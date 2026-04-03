<?php
require_once __DIR__ . '/../config.php';

class DPOService {
    private $companyToken;
    private $serviceType;
    private $baseUrl;
    private $callbackUrl;
    private $env;
    private $db;

    public function __construct($db = null) {
        $this->companyToken = env('DPO_COMPANY_TOKEN');
        $this->serviceType = env('DPO_SERVICE_TYPE', '3854');
        $this->env = env('DPO_ENV', 'sandbox');
        $this->callbackUrl = env('DPO_CALLBACK_URL');
        $this->db = $db;
        
        $this->baseUrl = ($this->env === 'production') 
            ? 'https://secure.3gdirectpay.com' 
            : 'https://secure1.sandbox.directpay.online';
    }

    /**
     * Create payment token (initialize transaction)
     * 
     * @param float $amount Payment amount
     * @param string $currency Currency code (USD, EUR, XAF, etc.)
     * @param string $reference Booking reference
     * @param string $customerEmail Customer email
     * @param string $customerName Customer name
     * @param string $customerPhone Customer phone
     * @return array Response data
     */
    public function createToken($amount, $currency, $reference, $customerEmail, $customerName, $customerPhone = '') {
        if (empty($this->companyToken)) {
            return [
                'status' => false,
                'message' => 'DPO_COMPANY_TOKEN not configured',
                'error_code' => 'CONFIG_ERROR'
            ];
        }

        $url = $this->baseUrl . '/payv2.php?ID=' . $this->companyToken;

        // Build XML request
        $xml = new SimpleXMLElement('<API3G/>');
        $xml->addChild('CompanyToken', $this->companyToken);
        $xml->addChild('Request', 'createToken');
        
        $transaction = $xml->addChild('Transaction');
        $transaction->addChild('PaymentAmount', number_format($amount, 2, '.', ''));
        $transaction->addChild('PaymentCurrency', $currency);
        $transaction->addChild('CompanyRef', $reference);
        $transaction->addChild('RedirectURL', $this->callbackUrl);
        $transaction->addChild('BackURL', $this->callbackUrl);
        $transaction->addChild('CompanyRefUnique', '1'); // Ensure unique reference
        $transaction->addChild('PTL', '5'); // Payment time limit in hours
        
        $services = $transaction->addChild('Services');
        $service = $services->addChild('Service');
        $service->addChild('ServiceType', $this->serviceType);
        $service->addChild('ServiceDescription', 'Flight Booking - ' . $reference);
        $service->addChild('ServiceDate', date('Y/m/d H:i'));

        // Add customer details
        if (!empty($customerEmail)) {
            $transaction->addChild('customerEmail', $customerEmail);
        }
        if (!empty($customerName)) {
            $transaction->addChild('customerFirstName', explode(' ', $customerName)[0]);
            $transaction->addChild('customerLastName', explode(' ', $customerName)[1] ?? '');
        }
        if (!empty($customerPhone)) {
            $transaction->addChild('customerPhone', $customerPhone);
        }

        $xmlString = $xml->asXML();

        $curl = curl_init();
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $xmlString,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT => 60,
            CURLOPT_HTTPHEADER => ['Content-Type: application/xml']
        ]);

        $response = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $curlError = curl_error($curl);
        curl_close($curl);

        if ($curlError) {
            $this->logError("cURL Error creating token: $curlError");
            return [
                'status' => false,
                'message' => 'Network error connecting to DPO',
                'error_code' => 'NETWORK_ERROR'
            ];
        }

        // Parse XML response
        try {
            $result = new SimpleXMLElement($response);
            
            // Log the request for debugging
            $this->logTransaction('CREATE_TOKEN', $reference, $xmlString, $response);
            
            if (isset($result->TransToken) && !empty((string)$result->TransToken)) {
                $transToken = (string)$result->TransToken;
                $transRef = (string)($result->TransRef ?? '');
                
                // Store the transaction
                $this->storeTransaction($transToken, $transRef, $reference, $amount, $currency);
                
                // Build payment URL
                $paymentUrl = $this->baseUrl . '/payv2.php?ID=' . $transToken;
                
                return [
                    'status' => true,
                    'message' => 'Payment token created successfully',
                    'data' => [
                        'trans_token' => $transToken,
                        'trans_ref' => $transRef,
                        'payment_url' => $paymentUrl,
                        'result' => (string)($result->Result ?? '000'),
                        'result_explanation' => (string)($result->ResultExplanation ?? '')
                    ]
                ];
            } else {
                $errorMessage = (string)($result->ResultExplanation ?? 'Failed to create payment token');
                $this->logError("Token creation failed: $errorMessage");
                
                return [
                    'status' => false,
                    'message' => $errorMessage,
                    'error_code' => (string)($result->Result ?? 'DPO_ERROR')
                ];
            }
        } catch (Exception $e) {
            $this->logError("Failed to parse DPO response: " . $e->getMessage());
            return [
                'status' => false,
                'message' => 'Invalid response from DPO',
                'error_code' => 'PARSE_ERROR'
            ];
        }
    }

    /**
     * Verify transaction status
     */
    public function verifyTransaction($transToken) {
        if (empty($this->companyToken)) {
            return ['status' => false, 'message' => 'DPO_COMPANY_TOKEN not configured'];
        }

        $url = $this->baseUrl . '/payv2.php?ID=' . $this->companyToken;

        // Build XML request
        $xml = new SimpleXMLElement('<API3G/>');
        $xml->addChild('CompanyToken', $this->companyToken);
        $xml->addChild('Request', 'verifyToken');
        $xml->addChild('TransactionToken', $transToken);

        $xmlString = $xml->asXML();

        $curl = curl_init();
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $xmlString,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_HTTPHEADER => ['Content-Type: application/xml']
        ]);

        $response = curl_exec($curl);
        $curlError = curl_error($curl);
        curl_close($curl);

        if ($curlError) {
            return ['status' => false, 'message' => 'Network error: ' . $curlError];
        }

        try {
            $result = new SimpleXMLElement($response);
            
            $resultCode = (string)($result->Result ?? '');
            $resultExplanation = (string)($result->ResultExplanation ?? '');
            $customerCredit = (string)($result->CustomerCredit ?? '0');
            $transactionApproval = (string)($result->TransactionApproval ?? '0');
            
            // Log verification
            $this->logTransaction('VERIFY_TOKEN', $transToken, $xmlString, $response);
            
            return [
                'status' => true,
                'transaction_status' => $resultCode === '000' ? 'success' : 'failed',
                'data' => [
                    'result' => $resultCode,
                    'result_explanation' => $resultExplanation,
                    'customer_credit' => $customerCredit,
                    'transaction_approval' => $transactionApproval,
                    'trans_token' => $transToken
                ]
            ];
        } catch (Exception $e) {
            return ['status' => false, 'message' => 'Invalid response from DPO'];
        }
    }

    /**
     * Process DPO callback/redirect
     */
    public function processCallback($callbackData) {
        $transToken = $callbackData['TransactionToken'] ?? $callbackData['trans_token'] ?? null;
        $companyRef = $callbackData['CompanyRef'] ?? $callbackData['reference'] ?? null;
        
        if (!$transToken) {
            $this->logError("Invalid callback - missing TransactionToken: " . json_encode($callbackData));
            return ['status' => false, 'message' => 'Invalid callback data'];
        }

        // Verify the transaction
        $verification = $this->verifyTransaction($transToken);
        
        if (!$verification['status']) {
            return $verification;
        }

        $transactionData = $verification['data'];
        $status = $transactionData['transaction_status'];
        
        // Get stored transaction
        $transaction = $this->getTransaction($transToken);
        $bookingReference = $transaction['booking_reference'] ?? $companyRef;
        
        $paymentData = [
            'trans_token' => $transToken,
            'status' => $status,
            'booking_reference' => $bookingReference,
            'result_code' => $transactionData['result'],
            'result_explanation' => $transactionData['result_explanation'],
            'amount' => $transaction['amount'] ?? 0,
            'currency' => $transaction['currency'] ?? 'USD'
        ];
        
        // Update the transaction
        $this->updateTransaction($transToken, $paymentData);
        
        return [
            'status' => true,
            'payment_status' => $status,
            'data' => $paymentData
        ];
    }

    /**
     * Refund transaction
     */
    public function refundTransaction($transToken, $amount, $reason = 'Booking cancellation') {
        // Note: DPO refunds typically require manual processing or separate API
        // This is a placeholder for the refund flow
        $this->logTransaction('REFUND_REQUEST', $transToken, ['amount' => $amount, 'reason' => $reason], null);
        
        return [
            'status' => false,
            'message' => 'DPO refunds require manual processing. Please contact support.',
            'data' => [
                'trans_token' => $transToken,
                'amount' => $amount,
                'reason' => $reason
            ]
        ];
    }

    /**
     * Store transaction in payment_transactions table
     */
    private function storeTransaction($transToken, $transRef, $bookingReference, $amount, $currency) {
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
                'trans_token' => $transToken,
                'trans_ref' => $transRef
            ]);
            
            $stmt = $this->db->prepare("
                INSERT INTO payment_transactions 
                (booking_id, user_id, amount, currency, payment_method, payment_reference, transaction_id, status, metadata, created_at)
                VALUES (?, ?, ?, ?, 'DPO', ?, ?, 'pending', ?, NOW())
            ");
            $stmt->execute([
                $booking['id'],
                $booking['user_id'] ?? 0,
                $amount,
                $currency,
                $bookingReference,
                $transToken,
                $metadata
            ]);
        } catch (Exception $e) {
            $this->logError("Failed to store transaction: " . $e->getMessage());
        }
    }

    /**
     * Get stored transaction
     */
    private function getTransaction($transToken) {
        if (!$this->db) return null;
        
        try {
            $stmt = $this->db->prepare("
                SELECT pt.*, b.booking_reference
                FROM payment_transactions pt
                LEFT JOIN bookings b ON pt.booking_id = b.id
                WHERE pt.transaction_id = ?
            ");
            $stmt->execute([$transToken]);
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            $this->logError("Failed to get transaction: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Update transaction with callback data
     */
    private function updateTransaction($transToken, $paymentData) {
        if (!$this->db) return;
        
        try {
            $status = $paymentData['status'] === 'success' ? 'completed' : 'failed';
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
                $transToken
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
            $logDir . '/dpo_' . date('Y-m-d') . '.log',
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
        file_put_contents($logDir . '/dpo_errors.log', $logEntry, FILE_APPEND);
    }
}
