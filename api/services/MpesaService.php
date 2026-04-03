<?php
require_once __DIR__ . '/../config.php';

class MpesaService {
    private $consumerKey;
    private $consumerSecret;
    private $shortCode;
    private $passkey;
    private $baseUrl;
    private $callbackUrl;
    private $env;
    private $db;

    public function __construct($db = null) {
        $this->consumerKey = env('MPESA_CONSUMER_KEY');
        $this->consumerSecret = env('MPESA_CONSUMER_SECRET');
        $this->shortCode = env('MPESA_SHORTCODE', '174379');
        $this->passkey = env('MPESA_PASSKEY', 'bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919');
        $this->env = env('MPESA_ENV', 'sandbox');
        $this->callbackUrl = env('MPESA_CALLBACK_URL');
        $this->db = $db;
        
        $this->baseUrl = ($this->env === 'production') 
            ? 'https://api.safaricom.co.ke' 
            : 'https://sandbox.safaricom.co.ke';
            
        date_default_timezone_set('Africa/Nairobi');
    }

    /**
     * Generate OAuth Access Token from Safaricom
     */
    public function getAccessToken() {
        if (empty($this->consumerKey) || empty($this->consumerSecret)) {
            $this->logError('Missing MPESA_CONSUMER_KEY or MPESA_CONSUMER_SECRET in environment');
            return null;
        }

        $credentials = base64_encode($this->consumerKey . ':' . $this->consumerSecret);
        $url = $this->baseUrl . '/oauth/v1/generate?grant_type=client_credentials';

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
            $this->logError("cURL Error getting access token: $curlError");
            return null;
        }
        
        $result = json_decode($response);
        
        if ($httpCode !== 200 || !isset($result->access_token)) {
            $this->logError("Failed to get access token. HTTP: $httpCode, Response: $response");
            return null;
        }
        
        $this->logTransaction('TOKEN_RESPONSE', null, null, $response);
        $this->logTransaction('TOKEN_GENERATED', null, null, ['status_code' => $httpCode, 'expires_in' => $result->expires_in ?? 'N/A']);
        return $result->access_token;
    }

    /**
     * Format phone number to 254XXXXXXXXX format
     */
    private function formatPhoneNumber($phoneNumber) {
        $phoneNumber = preg_replace('/\s+/', '', $phoneNumber); // Remove whitespace
        
        if (substr($phoneNumber, 0, 1) === '+') {
            $phoneNumber = substr($phoneNumber, 1);
        }
        
        if (substr($phoneNumber, 0, 1) === '0') {
            $phoneNumber = '254' . substr($phoneNumber, 1);
        }
        
        if (strlen($phoneNumber) === 9) {
            $phoneNumber = '254' . $phoneNumber;
        }
        
        return $phoneNumber;
    }

    /**
     * Initiate STK Push (M-Pesa Express / Lipa Na M-Pesa Online)
     */
    public function initiateStkPush($phoneNumber, $amount, $accountReference, $transactionDesc = 'Payment') {
        $accessToken = $this->getAccessToken();
        
        if (!$accessToken) {
            return [
                'status' => false, 
                'message' => 'Failed to authenticate with M-Pesa. Check API credentials.',
                'error_code' => 'AUTH_FAILED'
            ];
        }

        $url = $this->baseUrl . '/mpesa/stkpush/v1/processrequest';
        $timestamp = date('YmdHis');
        $password = base64_encode($this->shortCode . $this->passkey . $timestamp);
        $phoneNumber = $this->formatPhoneNumber($phoneNumber);
        $callbackUrl = $this->callbackUrl;

        if (empty($callbackUrl)) {
            return [
                'status' => false,
                'message' => 'MPESA_CALLBACK_URL not configured in environment',
                'error_code' => 'CONFIG_ERROR'
            ];
        }

        $payload = [
            'BusinessShortCode' => $this->shortCode,
            'Password' => $password,
            'Timestamp' => $timestamp,
            'TransactionType' => 'CustomerPayBillOnline',
            'Amount' => (int)round($amount),
            'PartyA' => $phoneNumber,
            'PartyB' => $this->shortCode,
            'PhoneNumber' => $phoneNumber,
            'CallBackURL' => $callbackUrl,
            'AccountReference' => substr($accountReference, 0, 12), // Max 12 chars
            'TransactionDesc' => substr($transactionDesc, 0, 13)    // Max 13 chars
        ];

        $curl = curl_init();
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $accessToken,
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
            $this->logError("cURL Error initiating STK Push: $curlError");
            return [
                'status' => false,
                'message' => 'Network error connecting to M-Pesa',
                'error_code' => 'NETWORK_ERROR'
            ];
        }
        
        $result = json_decode($response, true);
        
        // Log the request for debugging
        $this->logTransaction('STK_PUSH_REQUEST', $accountReference, $payload, $result);
        
        if (isset($result['ResponseCode']) && $result['ResponseCode'] === '0') {
            // Store the checkout request for later callback matching
            $this->storeCheckoutRequest(
                $result['CheckoutRequestID'],
                $result['MerchantRequestID'],
                $accountReference,
                $phoneNumber,
                $amount
            );
            
            return [
                'status' => true,
                'message' => 'STK Push sent successfully. Check your phone.',
                'data' => [
                    'MerchantRequestID' => $result['MerchantRequestID'],
                    'CheckoutRequestID' => $result['CheckoutRequestID'],
                    'ResponseCode' => $result['ResponseCode'],
                    'ResponseDescription' => $result['ResponseDescription'],
                    'CustomerMessage' => $result['CustomerMessage']
                ]
            ];
        } else {
            $errorMessage = $result['errorMessage'] ?? $result['ResponseDescription'] ?? 'Unknown error from M-Pesa';
            $this->logError("STK Push failed: $errorMessage. Full response: " . json_encode($result));
            
            return [
                'status' => false, 
                'message' => $errorMessage,
                'error_code' => $result['errorCode'] ?? 'MPESA_ERROR',
                'raw_response' => $result
            ];
        }
    }

    /**
     * Query STK Push transaction status
     */
    public function queryStkStatus($checkoutRequestId) {
        $accessToken = $this->getAccessToken();
        
        if (!$accessToken) {
            return ['status' => false, 'message' => 'Failed to authenticate with M-Pesa'];
        }

        $url = $this->baseUrl . '/mpesa/stkpushquery/v1/query';
        $timestamp = date('YmdHis');
        $password = base64_encode($this->shortCode . $this->passkey . $timestamp);

        $payload = [
            'BusinessShortCode' => $this->shortCode,
            'Password' => $password,
            'Timestamp' => $timestamp,
            'CheckoutRequestID' => $checkoutRequestId
        ];

        $curl = curl_init();
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json'
            ],
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($payload),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT => 30
        ]);

        $response = curl_exec($curl);
        $curlError = curl_error($curl);
        curl_close($curl);
        
        if ($curlError) {
            return ['status' => false, 'message' => 'Network error: ' . $curlError];
        }
        
        $result = json_decode($response, true);
        
        if (isset($result['ResultCode'])) {
            return [
                'status' => $result['ResultCode'] === '0',
                'result_code' => $result['ResultCode'],
                'result_desc' => $result['ResultDesc'],
                'data' => $result
            ];
        }
        
        return ['status' => false, 'message' => 'Invalid response from M-Pesa', 'raw' => $result];
    }

    /**
     * Process M-Pesa Callback
     */
    public function processCallback($callbackData) {
        if (!isset($callbackData['Body']['stkCallback'])) {
            $this->logError("Invalid callback structure: " . json_encode($callbackData));
            return ['status' => false, 'message' => 'Invalid callback data'];
        }
        
        $callback = $callbackData['Body']['stkCallback'];
        $merchantRequestId = $callback['MerchantRequestID'];
        $checkoutRequestId = $callback['CheckoutRequestID'];
        $resultCode = $callback['ResultCode'];
        $resultDesc = $callback['ResultDesc'];
        
        // Log the callback
        $this->logTransaction('CALLBACK_RECEIVED', $checkoutRequestId, null, $callback);
        
        // Get stored checkout request to find booking reference
        $checkoutRecord = $this->getCheckoutRequest($checkoutRequestId);
        $bookingReference = $checkoutRecord['booking_reference'] ?? null;
        
        $paymentData = [
            'merchant_request_id' => $merchantRequestId,
            'checkout_request_id' => $checkoutRequestId,
            'result_code' => $resultCode,
            'result_desc' => $resultDesc,
            'booking_reference' => $bookingReference,
            'status' => $resultCode == 0 ? 'success' : 'failed'
        ];
        
        if ($resultCode == 0 && isset($callback['CallbackMetadata']['Item'])) {
            // Payment successful - extract metadata
            foreach ($callback['CallbackMetadata']['Item'] as $item) {
                switch ($item['Name']) {
                    case 'Amount':
                        $paymentData['amount'] = $item['Value'];
                        break;
                    case 'MpesaReceiptNumber':
                        $paymentData['mpesa_receipt'] = $item['Value'];
                        break;
                    case 'TransactionDate':
                        $paymentData['transaction_date'] = $item['Value'];
                        break;
                    case 'PhoneNumber':
                        $paymentData['phone_number'] = $item['Value'];
                        break;
                }
            }
        }
        
        // Update the checkout record with callback data
        $this->updateCheckoutRequest($checkoutRequestId, $paymentData);
        
        return [
            'status' => true,
            'payment_status' => $paymentData['status'],
            'data' => $paymentData
        ];
    }

    /**
     * Store checkout request in payment_transactions table
     */
    private function storeCheckoutRequest($checkoutRequestId, $merchantRequestId, $bookingReference, $phoneNumber, $amount) {
        if (!$this->db) return;
        
        try {
            // Get booking_id from booking_reference (column is booking_reference)
            $stmt = $this->db->prepare("SELECT id, user_id FROM bookings WHERE booking_reference = ?");
            $stmt->execute([$bookingReference]);
            $booking = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$booking) {
                $this->logError("Booking not found for reference: $bookingReference");
                return;
            }
            
            $metadata = json_encode([
                'checkout_request_id' => $checkoutRequestId,
                'merchant_request_id' => $merchantRequestId,
                'phone_number' => $phoneNumber
            ]);
            
            $stmt = $this->db->prepare("
                INSERT INTO payment_transactions 
                (booking_id, user_id, amount, currency, payment_method, payment_reference, transaction_id, status, metadata, created_at)
                VALUES (?, ?, ?, 'KES', 'M-Pesa', ?, ?, 'pending', ?, NOW())
            ");
            $stmt->execute([
                $booking['id'],
                $booking['user_id'] ?? 0,
                $amount,
                $bookingReference,
                $checkoutRequestId,
                $metadata
            ]);
        } catch (Exception $e) {
            $this->logError("Failed to store checkout request: " . $e->getMessage());
        }
    }

    /**
     * Get stored checkout request from payment_transactions
     */
    private function getCheckoutRequest($checkoutRequestId) {
        if (!$this->db) return null;
        
        try {
            $stmt = $this->db->prepare("
                SELECT pt.*, b.booking_reference
                FROM payment_transactions pt
                LEFT JOIN bookings b ON pt.booking_id = b.id
                WHERE pt.transaction_id = ?
            ");
            $stmt->execute([$checkoutRequestId]);
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            $this->logError("Failed to get checkout request: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Update payment transaction with callback data
     */
    private function updateCheckoutRequest($checkoutRequestId, $paymentData) {
        if (!$this->db) return;
        
        try {
            $status = $paymentData['status'] === 'success' ? 'completed' : 'failed';
            $mpesaReceipt = $paymentData['mpesa_receipt'] ?? null;
            
            $metadata = json_encode($paymentData);
            
            $stmt = $this->db->prepare("
                UPDATE payment_transactions 
                SET status = ?, 
                    payment_reference = COALESCE(?, payment_reference),
                    payment_date = NOW(),
                    metadata = ?
                WHERE transaction_id = ?
            ");
            $stmt->execute([
                $status,
                $mpesaReceipt,
                $metadata,
                $checkoutRequestId
            ]);
        } catch (Exception $e) {
            $this->logError("Failed to update checkout request: " . $e->getMessage());
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
            $logDir . '/mpesa_' . date('Y-m-d') . '.log',
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
        file_put_contents($logDir . '/mpesa_errors.log', $logEntry, FILE_APPEND);
    }
}
