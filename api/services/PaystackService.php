<?php
require_once __DIR__ . '/../config.php';

class PaystackService {
    private $secretKey;
    private $publicKey;
    private $baseUrl = 'https://api.paystack.co';
    
    public function __construct() {
        $this->secretKey = env('PAYSTACK_SECRET_KEY', '');
        $this->publicKey = env('PAYSTACK_PUBLIC_KEY', '');
    }
    
    /**
     * Initialize a payment transaction
     * 
     * @param string $email Customer email
     * @param int $amount Amount in smallest currency unit (e.g. kobo/cents)
     * @param string $reference Unique transaction reference
     * @param array $metadata Additional transaction metadata
     * @param string $currency Currency code (default: KES)
     * @return array Response from Paystack API
     */
    public function initializeTransaction($email, $amount, $reference, $metadata = [], $currency = 'KES') {
        $url = $this->baseUrl . '/transaction/initialize';
        
        $fields = [
            'email' => $email,
            'amount' => $amount,
            'reference' => $reference,
            'currency' => $currency,
            'metadata' => $metadata,
            'callback_url' => env('APP_URL', '') . '/payment/callback'
        ];
        
        return $this->makeRequest('POST', $url, $fields);
    }
    
    /**
     * Verify a transaction
     * 
     * @param string $reference Transaction reference
     * @return array Response from Paystack API
     */
    public function verifyTransaction($reference) {
        $url = $this->baseUrl . '/transaction/verify/' . rawurlencode($reference);
        return $this->makeRequest('GET', $url);
    }
    
    /**
     * Get transaction details
     * 
     * @param string $reference Transaction reference
     * @return array Response from Paystack API
     */
    public function getTransaction($reference) {
        $url = $this->baseUrl . '/transaction/verify/' . rawurlencode($reference);
        return $this->makeRequest('GET', $url);
    }
    
    /**
     * Make HTTP request to Paystack API
     * 
     * @param string $method HTTP method
     * @param string $url API endpoint URL
     * @param array $data Request data
     * @return array Response data
     */
    private function makeRequest($method, $url, $data = []) {
        $ch = curl_init();
        
        $headers = [
            'Authorization: Bearer ' . $this->secretKey,
            'Content-Type: application/json',
            'Cache-Control: no-cache'
        ];
        
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        
        if (curl_errno($ch)) {
            $error = curl_error($ch);
            curl_close($ch);
            return [
                'status' => false,
                'message' => 'CURL Error: ' . $error
            ];
        }
        
        curl_close($ch);
        
        $result = json_decode($response, true);
        
        if ($httpCode !== 200) {
            return [
                'status' => false,
                'message' => $result['message'] ?? 'Payment gateway error',
                'http_code' => $httpCode
            ];
        }
        
        return $result;
    }
    
    /**
     * Get public key for client-side usage
     * 
     * @return string Public key
     */
    public function getPublicKey() {
        return $this->publicKey;
    }
}
?>
