<?php
require_once __DIR__ . '/../config.php';

class SmsService {
    private static $instance = null;
    private $accountSid;
    private $authToken;
    private $fromNumber;

    private function __construct() {
        $this->accountSid = env('TWILIO_ACCOUNT_SID', '');
        $this->authToken = env('TWILIO_AUTH_TOKEN', '');
        $this->fromNumber = env('TWILIO_FROM_NUMBER', '');
    }

    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    public function isConfigured(): bool {
        return !empty($this->accountSid) && !empty($this->authToken) && !empty($this->fromNumber);
    }

    /**
     * Send an SMS via Twilio REST API.
     */
    public function send(string $toNumber, string $message): bool {
        if (!$this->isConfigured()) return false;

        $toNumber = trim($toNumber);
        if ($toNumber === '') return false;

        $url = "https://api.twilio.com/2010-04-01/Accounts/{$this->accountSid}/Messages.json";

        $payload = http_build_query([
            'From' => $this->fromNumber,
            'To' => $toNumber,
            'Body' => $message
        ]);

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_USERPWD, $this->accountSid . ":" . $this->authToken);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/x-www-form-urlencoded'
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err = curl_error($ch);
        curl_close($ch);

        if ($httpCode >= 200 && $httpCode < 300) {
            return true;
        }

        error_log("Twilio SMS Error ({$httpCode}): " . ($response ?: 'no response'));
        if ($err) error_log("Twilio cURL Error: " . $err);
        return false;
    }
}

?>

