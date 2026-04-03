<?php

require_once __DIR__ . '/../../vendor/autoload.php';

class EmailService {
    private static $instance = null;
    private $apiKey;
    private $fromEmail;
    private $fromName;
    private $apiUrl = 'https://send.api.mailtrap.io/api/send';

    private function __construct() {
        $this->apiKey = env('MAILTRAP_API_KEY', '');
        $this->fromEmail = env('MAIL_FROM_ADDRESS', 'noreply@moonsunmedia.com');
        $this->fromName = env('MAIL_FROM_NAME', 'Airlogix');
    }

    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    public function sendPasswordReset($toEmail, $toName, $code) {
        $subject = 'Password Reset Code';
        
        // HTML email template
        $htmlContent = "
            <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>
                <h2 style='color: #333;'>Password Reset Code</h2>
                <p>Hello,</p>
                <p>We received a request to reset your password. Use the code below to complete the process:</p>
                <div style='margin: 25px 0; text-align: center;'>
                    <span style='
                        background-color: #f5f5f5;
                        color: #333;
                        font-family: monospace;
                        font-size: 24px;
                        padding: 12px 24px;
                        letter-spacing: 5px;
                        border: 1px solid #ddd;
                        border-radius: 5px;
                        display: inline-block;
                        font-weight: bold;
                    '>{$code}</span>
                </div>
                <p style='color: #666; font-size: 0.9em; margin-top: 20px;'>
                    <em>This code will expire in 15 minutes.</em>
                </p>
                <p style='color: #666; font-size: 0.9em;'>
                    If you didn't request this, please ignore this email.
                </p>
                <p>Thanks,<br>{$this->fromName} Team</p>
            </div>
        ";
        
        // Plain text version
        $textContent = "Password Reset Code\n\n" .
            "Hello,\n\n" .
            "We received a request to reset your password. Use the code below:\n\n" .
            "{$code}\n\n" .
            "This code will expire in 15 minutes.\n\n" .
            "If you didn't request this, please ignore this email.\n\n" .
            "Thanks,\n{$this->fromName} Team";

        return $this->sendMailtrapRequest([
            'from' => [
                'email' => $this->fromEmail,
                'name' => $this->fromName
            ],
            'to' => [
                ['email' => $toEmail, 'name' => $toName]
            ],
            'subject' => $subject,
            'text' => $textContent,
            'html' => $htmlContent,
            'category' => 'password_reset'
        ]);
    }

    public function sendTicket($toEmail, $toName, $ticketHtml, $subject) {
        $data = [
            'from' => [
                'email' => $this->fromEmail,
                'name' => $this->fromName
            ],
            'to' => [
                ['email' => $toEmail, 'name' => $toName]
            ],
            'subject' => $subject,
            'html' => $ticketHtml,
            'category' => 'ticket_issuance'
        ];

        return $this->sendMailtrapRequest($data);
    }

    public function sendBookingAccessCode($toEmail, $toName, $reference, $code) {
        $subject = "Your booking access code [" . $reference . "]";

        $htmlContent = "
            <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>
                <h2 style='color: #333;'>Booking Access Code</h2>
                <p>Hello {$toName},</p>
                <p>Use the code below to access your booking <strong>{$reference}</strong>:</p>
                <div style='margin: 25px 0; text-align: center;'>
                    <span style='
                        background-color: #f5f5f5;
                        color: #333;
                        font-family: monospace;
                        font-size: 24px;
                        padding: 12px 24px;
                        letter-spacing: 5px;
                        border: 1px solid #ddd;
                        border-radius: 5px;
                        display: inline-block;
                        font-weight: bold;
                    '>{$code}</span>
                </div>
                <p style='color: #666; font-size: 0.9em; margin-top: 20px;'>
                    <em>This code will expire in 10 minutes.</em>
                </p>
                <p style='color: #666; font-size: 0.9em;'>
                    If you didn't request this, you can ignore this email.
                </p>
                <p>Thanks,<br>{$this->fromName} Team</p>
            </div>
        ";

        return $this->sendMailtrapRequest([
            'from' => [
                'email' => $this->fromEmail,
                'name' => $this->fromName
            ],
            'to' => [
                ['email' => $toEmail, 'name' => $toName]
            ],
            'subject' => $subject,
            'html' => $htmlContent,
            'category' => 'booking_access'
        ]);
    }
    
    private function sendMailtrapRequest($data) {
        $ch = curl_init($this->apiUrl);
        
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Api-Token: ' . $this->apiKey
        ]);
        
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        
        curl_close($ch);
        
        if ($httpCode >= 200 && $httpCode < 300) {
            return true;
        } else {
            error_log("Mailtrap API Error ({$httpCode}): " . $response);
            if ($error) {
                error_log("cURL Error: " . $error);
            }
            return false;
        }
    }
}
?>
