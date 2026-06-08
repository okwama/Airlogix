<?php

require_once __DIR__ . '/../config.php';

class CloudinaryService {
    private static $instance = null;
    private $cloudName;
    private $apiKey;
    private $apiSecret;
    private $uploadUrl;
    
    private function __construct() {
        $this->cloudName = env('CLOUDINARY_CLOUD_NAME', '');
        $this->apiKey = env('CLOUDINARY_API_KEY', '');
        $this->apiSecret = env('CLOUDINARY_API_SECRET', '');
        $this->uploadUrl = "https://api.cloudinary.com/v1_1/{$this->cloudName}/auto/upload";
        
        if (empty($this->cloudName) || empty($this->apiKey) || empty($this->apiSecret)) {
            error_log('Cloudinary credentials not configured');
        }
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * Upload file to Cloudinary
     * @param string $filePath Temporary file path
     * @param string $folder Optional folder in Cloudinary
     * @return array|null Returns ['secure_url' => string, 'public_id' => string] or null on failure
     */
    public function uploadFile(string $filePath, string $folder = 'leave_attachments'): ?array {
        if (empty($this->cloudName) || empty($this->apiKey) || empty($this->apiSecret)) {
            error_log('Cloudinary not configured');
            return null;
        }
        
        if (!file_exists($filePath)) {
            error_log("File not found: $filePath");
            return null;
        }
        
        // Generate signature for authenticated upload
        $timestamp = time();
        
        // Prepare file for upload
        $cfile = new CURLFile($filePath);
        $cfile->setPostFilename(basename($filePath));
        
        // Use signed upload by default (more reliable when credentials are available)
        // Signed uploads don't require upload_preset and work with API credentials
        $params = [
            'folder' => $folder,
            'timestamp' => $timestamp
        ];
        $signature = $this->generateSignature($params);
        
        $postData = [
            'file' => $cfile,
            'folder' => $folder,
            'timestamp' => $timestamp,
            'api_key' => $this->apiKey,
            'signature' => $signature
        ];
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $this->uploadUrl);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode !== 200) {
            error_log("Cloudinary upload failed: HTTP $httpCode - $response");
            return null;
        }
        
        $result = json_decode($response, true);
        if (isset($result['secure_url']) && isset($result['public_id'])) {
            return [
                'secure_url' => $result['secure_url'],
                'public_id' => $result['public_id'],
                'format' => $result['format'] ?? null,
                'bytes' => $result['bytes'] ?? 0
            ];
        }
        
        error_log("Cloudinary upload response missing required fields: $response");
        return null;
    }
    
    /**
     * Generate signature for Cloudinary upload
     * Parameters must be sorted alphabetically and concatenated
     */
    private function generateSignature(array $params): string {
        // Sort parameters alphabetically
        ksort($params);
        
        // Build signature string: param1=value1&param2=value2 + secret
        $signatureParts = [];
        foreach ($params as $key => $value) {
            $signatureParts[] = "$key=$value";
        }
        $signatureString = implode('&', $signatureParts) . $this->apiSecret;
        
        return sha1($signatureString);
    }
    
    /**
     * Delete file from Cloudinary
     */
    public function deleteFile(string $publicId): bool {
        if (empty($this->cloudName) || empty($this->apiKey) || empty($this->apiSecret)) {
            return false;
        }
        
        $timestamp = time();
        $signature = sha1("public_id=$publicId&timestamp=$timestamp" . $this->apiSecret);
        
        $data = [
            'public_id' => $publicId,
            'timestamp' => $timestamp,
            'api_key' => $this->apiKey,
            'signature' => $signature
        ];
        
        $url = "https://api.cloudinary.com/v1_1/{$this->cloudName}/auto/destroy";
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        return $httpCode === 200;
    }
}

