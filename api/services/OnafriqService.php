<?php
require_once __DIR__ . '/../config.php';

class OnafriqService {
    private $apiKey;
    private $apiSecret;
    private $merchantId;
    private $baseUrl;
    private $callbackUrl;
    private $env;
    private $db;

    public function __construct($db = null) {
        $this->apiKey = env('ONAFRIQ_API_KEY');
        $this->apiSecret = env('ONAFRIQ_API_SECRET');
        $this->merchantId = env('ONAFRIQ_MERCHANT_ID');
        $this->env = env('ONAFRIQ_ENV', 'sandbox');
        $this->callbackUrl = env('ONAFRIQ_CALLBACK_URL');
        $this->db = $db;
        
        $this->baseUrl = ($this->env === 'production') 
            ? 'https://api.onafriq.com' 
            : 'https://sandbox.onafriq.com';
    }

    /**
     * Generate authentication token for API requests
     */
    private function getAuthToken() {
        if (empty($this->apiKey) || empty($this->apiSecret)) {
            $this->logError('Missing ONAFRIQ_API_KEY or ONAFRIQ_API_SECRET in environment');
            return null;
        }

        $credentials = base64_encode($this->apiKey . ':' . $this->apiSecret);
        $url = $this->baseUrl . '/v1/auth/token';

        $curl = curl_init();
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_HTTPHEADER => ['Authorization: Basic ' . $credentials],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT => 30
        ]);
        
        $response = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $curlError = curl_error($curl);
        curl_close($curl);
        
        if ($curlError) {
            $this->logError("cURL Error getting auth token: $curlError");
            return null;
        }
        
        $result = json_decode($response);
        
        if ($httpCode !== 200 || !isset($result->access_token)) {
            $this->logError("Failed to get auth token. HTTP: $httpCode, Response: $response");
            return null;
        }
        
        return $result->access_token;
    }

    /**
     * Format phone number to international format
     */
    private function formatPhoneNumber($phoneNumber, $countryCode = '243') {
        $phoneNumber = preg_replace('/\s+/', '', $phoneNumber);
        
        if (substr($phoneNumber, 0, 1) === '+') {
            $phoneNumber = substr($phoneNumber, 1);
        }
        
        if (substr($phoneNumber, 0, 1) === '0') {
            $phoneNumber = $countryCode . substr($phoneNumber, 1);
        }
        
        if (strlen($phoneNumber) === 9) {
            $phoneNumber = $countryCode . $phoneNumber;
        }
        
        return $phoneNumber;
    }

    /**
     * Initiate Mobile Money payment collection
     * 
     * @param string $phoneNumber Customer phone number
     * @param float $amount Amount to collect
     * @param string $currency Currency code (XAF, CDF, etc.)
     * @param string $accountReference Booking reference
     * @param string $provider Mobile money provider (orange, mtn, airtel)
     * @param string $countryCode Country code for phone formatting
     * @return array Response data
     */
    public function initiateMobileMoneyPayment($phoneNumber, $amount, $currency, $accountReference, $provider = 'orange', $countryCode = '243') {
        $authToken = $this->getAuthToken();
        
        if (!$authToken) {
            return [
                'status' => false, 
                'message' => 'Failed to authenticate with Onafriq. Check API credentials.',
                'error_code' => 'AUTH_FAILED'
            ];
        }

        $url = $this->baseUrl . '/v1/collections';
        $phoneNumber = $this->formatPhoneNumber($phoneNumber, $countryCode);
        $callbackUrl = $this->callbackUrl;

        if (empty($callbackUrl)) {
            return [
                'status' => false,
                'message' => 'ONAFRIQ_CALLBACK_URL not configured in environment',
                'error_code' => 'CONFIG_ERROR'
            ];
        }

        $payload = [
            'merchant_id' => $this->merchantId,
            'amount' => round($amount, 2),
            'currency' => $currency,
            'phone_number' => $phoneNumber,
            'provider' => $provider,
            'reference' => $accountReference,
            'callback_url' => $callbackUrl,
            'description' => 'Flight booking payment - ' . $accountReference
        ];

        $curl = curl_init();
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $authToken,
                'Content-Type: application/json'
            ],
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($payload),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT => 60
        ]);

        $response = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $curlError = curl_error($curl);
        curl_close($curl);
        
        if ($curlError) {
            $this->logError("cURL Error initiating payment: $curlError");
            return [
                'status' => false,
                'message' => 'Network error connecting to Onafriq',
                'error_code' => 'NETWORK_ERROR'
            ];
        }
        
        $result = json_decode($response, true);
        
        // Log the request for debugging
        $this->logTransaction('PAYMENT_REQUEST', $accountReference, $payload, $result);
        
        if ($httpCode === 200 && isset($result['transaction_id'])) {
            // Store the transaction for later callback matching
            $this->storeTransaction(
                $result['transaction_id'],
                $accountReference,
                $phoneNumber,
                $amount,
                $currency,
                $provider
            );
            
            return [
                'status' => true,
                'message' => 'Payment initiated successfully. Please complete on your phone.',
                'data' => [
                    'transaction_id' => $result['transaction_id'],
                    'status' => $result['status'] ?? 'pending',
                    'provider' => $provider,
                    'amount' => $amount,
                    'currency' => $currency
                ]
            ];
        } else {
            $errorMessage = $result['message'] ?? $result['error'] ?? 'Unknown error from Onafriq';
            $this->logError("Payment initiation failed: $errorMessage. Full response: " . json_encode($result));
            
            return [
                'status' => false, 
                'message' => $errorMessage,
                'error_code' => $result['error_code'] ?? 'ONAFRIQ_ERROR',
                'raw_response' => $result
            ];
        }
    }

    /**
     * Query transaction status
     */
    public function queryTransactionStatus($transactionId) {
        $authToken = $this->getAuthToken();
        
        if (!$authToken) {
            return ['status' => false, 'message' => 'Failed to authenticate with Onafriq'];
        }

        $url = $this->baseUrl . '/v1/collections/' . $transactionId;

        $curl = curl_init();
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $authToken,
                'Content-Type: application/json'
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT => 30
        ]);

        $response = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $curlError = curl_error($curl);
        curl_close($curl);
        
        if ($curlError) {
            return ['status' => false, 'message' => 'Network error: ' . $curlError];
        }
        
        $result = json_decode($response, true);
        
        if ($httpCode === 200 && isset($result['status'])) {
            return [
                'status' => true,
                'transaction_status' => $result['status'],
                'data' => $result
            ];
        }
        
        return ['status' => false, 'message' => 'Invalid response from Onafriq', 'raw' => $result];
    }

    /**
     * Process Onafriq callback
     */
    public function processCallback($callbackData) {
        if (!isset($callbackData['transaction_id'])) {
            $this->logError("Invalid callback structure: " . json_encode($callbackData));
            return ['status' => false, 'message' => 'Invalid callback data'];
        }
        
        $transactionId = $callbackData['transaction_id'];
        $status = $callbackData['status'] ?? 'unknown';
        $reference = $callbackData['reference'] ?? null;
        
        // Log the callback
        $this->logTransaction('CALLBACK_RECEIVED', $reference, null, $callbackData);
        
        // Get stored transaction to find booking reference
        $transaction = $this->getTransaction($transactionId);
        $bookingReference = $transaction['booking_reference'] ?? $reference;
        
        $paymentData = [
            'transaction_id' => $transactionId,
            'status' => $status,
            'booking_reference' => $bookingReference,
            'amount' => $callbackData['amount'] ?? $transaction['amount'] ?? 0,
            'currency' => $callbackData['currency'] ?? $transaction['currency'] ?? 'XAF',
            'provider' => $callbackData['provider'] ?? $transaction['provider'] ?? 'unknown',
            'phone_number' => $callbackData['phone_number'] ?? $transaction['phone_number'] ?? null
        ];
        
        // Update the transaction with callback data
        $this->updateTransaction($transactionId, $paymentData);
        
        return [
            'status' => true,
            'payment_status' => $status,
            'data' => $paymentData
        ];
    }

    /**
     * Disburse funds (refunds)
     */
    public function disburseFunds($phoneNumber, $amount, $currency, $reference, $provider = 'orange', $countryCode = '243') {
        $authToken = $this->getAuthToken();
        
        if (!$authToken) {
            return ['status' => false, 'message' => 'Failed to authenticate with Onafriq'];
        }

        $url = $this->baseUrl . '/v1/disbursements';
        $phoneNumber = $this->formatPhoneNumber($phoneNumber, $countryCode);

        $payload = [
            'merchant_id' => $this->merchantId,
            'amount' => round($amount, 2),
            'currency' => $currency,
            'phone_number' => $phoneNumber,
            'provider' => $provider,
            'reference' => $reference,
            'description' => 'Refund for booking - ' . $reference
        ];

        $curl = curl_init();
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $authToken,
                'Content-Type: application/json'
            ],
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($payload),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT => 60
        ]);

        $response = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        
        $result = json_decode($response, true);
        
        if ($httpCode === 200 && isset($result['transaction_id'])) {
            return [
                'status' => true,
                'message' => 'Refund initiated successfully',
                'data' => $result
            ];
        }
        
        return [
            'status' => false,
            'message' => $result['message'] ?? 'Refund failed',
            'raw_response' => $result
        ];
    }

    /**
     * Store transaction in payment_transactions table
     */
    private function storeTransaction($transactionId, $bookingReference, $phoneNumber, $amount, $currency, $provider) {
        if (!$this->db) return;
        
        try {
            // Get booking_id from booking_reference
            $stmt = $this->db->prepare("SELECT id, user_id FROM bookings WHERE booking_reference = ?");
            $stmt->execute([$bookingReference]);
            $booking = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$booking) {
                $this->logError("Booking not found for reference: $bookingReference");
                return;
            }
            
            $metadata = json_encode([
                'transaction_id' => $transactionId,
                'phone_number' => $phoneNumber,
                'provider' => $provider
            ]);
            
            $stmt = $this->db->prepare("
                INSERT INTO payment_transactions 
                (booking_id, user_id, amount, currency, payment_method, payment_reference, transaction_id, status, metadata, created_at)
                VALUES (?, ?, ?, ?, 'Onafriq', ?, ?, 'pending', ?, NOW())
            ");
            $stmt->execute([
                $booking['id'],
                $booking['user_id'] ?? 0,
                $amount,
                $currency,
                $bookingReference,
                $transactionId,
                $metadata
            ]);
        } catch (Exception $e) {
            $this->logError("Failed to store transaction: " . $e->getMessage());
        }
    }

    /**
     * Get stored transaction from payment_transactions
     */
    private function getTransaction($transactionId) {
        if (!$this->db) return null;
        
        try {
            $stmt = $this->db->prepare("
                SELECT pt.*, b.reference as booking_reference 
                FROM payment_transactions pt
                LEFT JOIN bookings b ON pt.booking_id = b.id
                WHERE pt.transaction_id = ?
            ");
            $stmt->execute([$transactionId]);
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            $this->logError("Failed to get transaction: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Update payment transaction with callback data
     */
    private function updateTransaction($transactionId, $paymentData) {
        if (!$this->db) return;
        
        try {
            $status = ($paymentData['status'] === 'success' || $paymentData['status'] === 'completed') ? 'completed' : 'failed';
            $metadata = json_encode($paymentData);
            
            $stmt = $this->db->prepare("
                UPDATE payment_transactions 
                SET status = ?, 
                    payment_date = NOW(),
                    metadata = ?
                WHERE transaction_id = ?
            ");
            $stmt->execute([
                $status,
                $metadata,
                $transactionId
            ]);
        } catch (Exception $e) {
            $this->logError("Failed to update transaction: " . $e->getMessage());
        }
    }

    /**
     * Log transaction for debugging
     */
    private function logTransaction($type, $reference, $request, $response) {
        $logDir = __DIR__ . '/../logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'type' => $type,
            'reference' => $reference,
            'request' => $request,
            'response' => $response
        ];
        
        file_put_contents(
            $logDir . '/onafriq_' . date('Y-m-d') . '.log',
            json_encode($logEntry) . PHP_EOL,
            FILE_APPEND
        );
    }

    /**
     * Log errors
     */
    private function logError($message) {
        $logDir = __DIR__ . '/../logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        
        $logEntry = date('Y-m-d H:i:s') . " ERROR: $message" . PHP_EOL;
        file_put_contents($logDir . '/onafriq_errors.log', $logEntry, FILE_APPEND);
    }
}
