<?php
require_once __DIR__ . '/../config.php';

/**
 * StripeService handles interactions with the Stripe API.
 * We use Stripe Checkout (Sessions) for a secure, redirect-based payment flow.
 */
class StripeService {
    private $secretKey;
    private $baseUrl = 'https://api.stripe.com/v1';

    public function __construct() {
        $this->secretKey = env('STRIPE_SECRET_KEY', '');
    }

    /**
     * Create a Stripe Checkout Session
     * 
     * @param float $amount Amount (e.g., 250.00)
     * @param string $currency (e.g., "USD" or "EUR")
     * @param string $bookingReference Unique PNR
     * @param string $customerEmail
     * @return array
     */
    public function createCheckoutSession($amount, $currency, $bookingReference, $customerEmail) {
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
        
        // Ensure frontend URL is properly set for redirects
        $frontendUrl = env('APP_URL_FRONTEND', 'https://impulsepromotions.co.ke');
        
        $fields = [
            'success_url' => $frontendUrl . '/booking/' . $bookingReference . '/success?session_id={CHECKOUT_SESSION_ID}',
            'cancel_url' => $frontendUrl . '/booking/' . $bookingReference,
            'mode' => 'payment',
            'customer_email' => $customerEmail,
            'client_reference_id' => $bookingReference,
            'line_items' => [
                [
                    'price_data' => [
                        'currency' => strtolower($currency),
                        'product_data' => [
                            'name' => 'Flight Booking: ' . $bookingReference,
                            'description' => 'Travel booking via Mc Aviation / AirLogix'
                        ],
                        'unit_amount' => $amountInCents,
                    ],
                    'quantity' => 1,
                ]
            ],
            'metadata' => [
                'booking_reference' => $bookingReference
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
