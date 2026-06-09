<?php
require_once __DIR__ . '/../config.php';

/**
 * StripeService handles interactions with the Stripe API.
 * We use Stripe Checkout (Sessions) for a secure, redirect-based payment flow.
 *
 * Return URLs:
 * - channel "web": APP_URL_FRONTEND + /booking/{ref}/success|cancel paths (SvelteKit).
 * - channel "android" | "ios": deep links airlogix://payment/result (override via .env if needed).
 *
 * Optional .env:
 * - STRIPE_MOBILE_SUCCESS_URL — must contain literal {CHECKOUT_SESSION_ID}; use {REFERENCE} for PNR.
 * - STRIPE_MOBILE_CANCEL_URL — use {REFERENCE} for PNR.
 */
class StripeService {
    private $secretKey;
    private $baseUrl = 'https://api.stripe.com/v1';

    public function __construct() {
        $this->secretKey = env('STRIPE_SECRET_KEY', '');
    }

    /**
     * Normalize client channel for metadata and return URLs.
     *
     * @param string $clientChannel web | android | ios
     * @return string
     */
    private function normalizeClientChannel($clientChannel) {
        $c = strtolower(trim((string)$clientChannel));
        if (in_array($c, ['web', 'android', 'ios'], true)) {
            return $c;
        }
        return 'web';
    }

    /**
     * Build success/cancel URLs for Checkout (web vs native deep links).
     *
     * @param string $bookingReference
     * @param string $channel web|android|ios
     * @return array{success:string,cancel:string}
     */
    private function buildCheckoutReturnUrls($bookingReference, $channel) {
        $refEnc = rawurlencode((string)$bookingReference);
        $frontendUrl = rtrim((string)env('APP_URL_FRONTEND', 'https://impulsepromotions.co.ke'), '/');

        if ($channel === 'web') {
            return [
                'success' => $frontendUrl . '/booking/' . $refEnc . '/success?session_id={CHECKOUT_SESSION_ID}',
                'cancel' => $frontendUrl . '/booking/' . $refEnc,
            ];
        }

        $successOverride = (string)env('STRIPE_MOBILE_SUCCESS_URL', '');
        if ($successOverride !== '') {
            $successUrl = str_replace(
                    ['{CHECKOUT_SESSION_ID}', '{REFERENCE}', '{reference}'],
                    ['{CHECKOUT_SESSION_ID}', $refEnc, $refEnc],
                    $successOverride
            );
        } else {
            $successUrl = 'airlogix://payment/result?status=success&reference=' . $refEnc . '&session_id={CHECKOUT_SESSION_ID}';
        }

        $cancelOverride = (string)env('STRIPE_MOBILE_CANCEL_URL', '');
        if ($cancelOverride !== '') {
            $cancelUrl = str_replace(['{REFERENCE}', '{reference}'], [$refEnc, $refEnc], $cancelOverride);
        } else {
            $cancelUrl = 'airlogix://payment/result?status=cancelled&reference=' . $refEnc;
        }

        return ['success' => $successUrl, 'cancel' => $cancelUrl];
    }

    /**
     * Create a Stripe Checkout Session
     *
     * @param float $amount Amount (e.g., 250.00)
     * @param string $currency (e.g., "USD" or "EUR")
     * @param string $bookingReference Unique PNR
     * @param string $customerEmail
     * @param string $clientChannel web|android|ios — controls success/cancel URLs and metadata
     * @return array
     */
    public function createCheckoutSession($amount, $currency, $bookingReference, $customerEmail, $clientChannel = 'web') {
        if (empty($this->secretKey)) {
            return [
                'status' => false,
                'message' => 'Stripe is not configured on the server.',
                'error_code' => 'STRIPE_CONFIG_MISSING'
            ];
        }

        if (empty($customerEmail) || !filter_var((string)$customerEmail, FILTER_VALIDATE_EMAIL)) {
            return [
                'status' => false,
                'message' => 'A valid customer email is required for Stripe checkout.',
                'error_code' => 'STRIPE_CUSTOMER_EMAIL_INVALID'
            ];
        }

        $url = $this->baseUrl . '/checkout/sessions';

        // Stripe expects amounts in the smallest currency unit (cents/kobo)
        $amountInCents = (int)(round($amount, 2) * 100);

        $channel = $this->normalizeClientChannel($clientChannel);
        $urls = $this->buildCheckoutReturnUrls($bookingReference, $channel);

        $fields = [
            'success_url' => $urls['success'],
            'cancel_url' => $urls['cancel'],
            'mode' => 'payment',
            'customer_email' => $customerEmail,
            'client_reference_id' => $bookingReference,
            'line_items' => [
                [
                    'price_data' => [
                        'currency' => strtolower($currency),
                        'product_data' => [
                            'name' => 'Flight Booking: ' . $bookingReference,
                            'description' => 'Travel booking via Royal Air / AirLogix'
                        ],
                        'unit_amount' => $amountInCents,
                    ],
                    'quantity' => 1,
                ]
            ],
            'metadata' => [
                'booking_reference' => $bookingReference,
                'channel' => $channel,
            ]
        ];

        error_log("Initiating Stripe Session for Ref: $bookingReference, Email: $customerEmail, Amount: $amount $currency");
        
        // Stripe uses application/x-www-form-urlencoded with nested arrays support
        $response = $this->makeRequest('POST', $url, $fields);
        
        if (!$response['status']) {
            error_log("Stripe Session Creation Failed for Ref: $bookingReference. Error: " . $response['message']);
        } else {
            error_log("Stripe Session Created Successfully for Ref: $bookingReference. Session ID: " . ($response['data']['id'] ?? 'N/A'));
        }

        return $response;
    }

    /**
     * Retrieve a session to verify its status
     */
    public function retrieveSession($sessionId) {
        $url = $this->baseUrl . '/checkout/sessions/' . $sessionId;
        return $this->makeRequest('GET', $url);
    }

    /**
     * Helper to make cURL requests to Stripe
     */
    private function makeRequest($method, $url, $data = []) {
        $ch = curl_init();
        
        $headers = [
            'Authorization: Bearer ' . $this->secretKey,
            'Content-Type: application/x-www-form-urlencoded'
        ];

        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            // http_build_query handles the nested array format Stripe requires
            curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));
        }

        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

        $responseBody = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

        if (curl_errno($ch)) {
            $error = curl_error($ch);
            curl_close($ch);
            error_log("Stripe cURL Error: " . $error);
            return [
                'status' => false,
                'message' => 'Stripe Connection Error: ' . $error,
                'error_code' => 'STRIPE_NETWORK_ERROR'
            ];
        }

        curl_close($ch);
        $result = json_decode($responseBody, true);

        if ($httpCode >= 400) {
            $stripeCode = (string)($result['error']['code'] ?? '');
            $errorCode = $stripeCode !== '' ? 'STRIPE_' . strtoupper($stripeCode) : 'STRIPE_API_ERROR';
            error_log("Stripe API Error (Code $httpCode): " . ($result['error']['message'] ?? 'Unknown Error'));
            return [
                'status' => false,
                'message' => $result['error']['message'] ?? 'Stripe API Error',
                'error_code' => $errorCode,
                'http_code' => $httpCode,
                'raw_response' => $result
            ];
        }

        return ['status' => true, 'data' => $result];
    }
}
?>
