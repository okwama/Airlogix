<?php

require_once __DIR__ . '/../vendor/autoload.php';

use PHPMailer\PHPMailer\Exception as PhpMailerException;
use PHPMailer\PHPMailer\PHPMailer;

class EmailService {
    private static $instance = null;
    private $apiKey;
    private $fromEmail;
    private $fromName;
    private $apiUrl = 'https://send.api.mailtrap.io/api/send';

    private function __construct() {
        $this->apiKey = env('MAILTRAP_API_KEY', '');
        $this->fromEmail = env('MAIL_FROM_ADDRESS', 'info@impulsepromotions.co.ke');
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

    public function sendCargoAccessCode($toEmail, $toName, $awb, $code) {
        $subject = "Your cargo access code [" . $awb . "]";

        $htmlContent = "
            <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>
                <h2 style='color: #333;'>Cargo Access Code</h2>
                <p>Hello {$toName},</p>
                <p>Use the code below to access shipment <strong>{$awb}</strong>:</p>
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
            'category' => 'cargo_access'
        ]);
    }

    public function sendReservationHold($toEmail, $toName, $reference, $expiresAt, $manageUrl) {
        $subject = "Complete payment for your reserved seats [" . $reference . "]";
        $safeName = trim((string)$toName) !== '' ? $toName : 'Traveler';
        $expiryLabel = trim((string)$expiresAt) !== '' ? $expiresAt : 'the hold expiry time shown in your booking';
        $manageUrl = trim((string)$manageUrl);

        $htmlContent = "
            <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1f2937;'>
                <h2 style='color: #0f172a; margin-bottom: 12px;'>Your seats are reserved temporarily</h2>
                <p>Hello {$safeName},</p>
                <p>Your booking reference is <strong>{$reference}</strong>.</p>
                <p>Please complete payment before <strong>{$expiryLabel}</strong> or the reservation will expire automatically and the seats will be released.</p>
                <div style='margin: 24px 0; padding: 18px; border: 1px solid #dbeafe; background: #eff6ff; border-radius: 10px;'>
                    <p style='margin: 0 0 8px; font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; color: #1d4ed8;'>Booking reference</p>
                    <p style='margin: 0; font-family: monospace; font-size: 26px; font-weight: 700; color: #0f172a;'>{$reference}</p>
                </div>
                <p>You can return to your booking at any time during the hold window and continue payment securely.</p>"
                . (!empty($manageUrl)
                    ? "<p style='margin-top: 24px;'><a href='{$manageUrl}' style='display: inline-block; background: #0f172a; color: #ffffff; text-decoration: none; padding: 12px 18px; border-radius: 8px; font-weight: 600;'>Manage booking</a></p>"
                    : '')
                . "<p style='color: #6b7280; font-size: 0.92em; margin-top: 24px;'>
                    If you leave the payment page, use your booking reference and booking email on the Manage Booking page to continue.
                </p>
                <p>Thanks,<br>{$this->fromName} Team</p>
            </div>
        ";

        $textContent = "Your seats are reserved temporarily\n\n"
            . "Hello {$safeName},\n\n"
            . "Your booking reference is {$reference}.\n"
            . "Please complete payment before {$expiryLabel} or the reservation will expire automatically.\n\n"
            . (!empty($manageUrl) ? "Manage booking: {$manageUrl}\n\n" : '')
            . "If you leave the payment page, use your booking reference and booking email on the Manage Booking page to continue.\n\n"
            . "Thanks,\n{$this->fromName} Team";

        return $this->sendMailtrapRequest([
            'from' => [
                'email' => $this->fromEmail,
                'name' => $this->fromName
            ],
            'to' => [
                ['email' => $toEmail, 'name' => $safeName]
            ],
            'subject' => $subject,
            'text' => $textContent,
            'html' => $htmlContent,
            'category' => 'reservation_hold'
        ]);
    }
    
    /** True when Sending API key and/or Mailtrap SMTP credentials are set (see .env.example). */
    public function isConfigured(): bool
    {
        return trim((string)$this->apiKey) !== '' || $this->smtpConfigured();
    }

    private function smtpConfigured(): bool
    {
        $user = trim((string)env('MAILTRAP_SMTP_USER', ''));
        $pass = trim((string)env('MAILTRAP_SMTP_PASS', ''));
        return $user !== '' && $pass !== '';
    }

    private function sendMailtrapRequest(array $data): bool
    {
        if (!$this->isConfigured()) {
            error_log('Mailtrap: configure MAILTRAP_API_KEY and/or MAILTRAP_SMTP_USER + MAILTRAP_SMTP_PASS.');
            return false;
        }

        $mode = strtolower(trim((string)env('MAIL_TRANSPORT', 'auto')));
        if ($mode === 'smtp') {
            return $this->sendViaSmtp($data);
        }
        if ($mode === 'api') {
            return $this->sendViaApi($data);
        }

        if ($this->sendViaApi($data)) {
            return true;
        }
        error_log('Mailtrap: Sending API failed; trying SMTP fallback.');
        return $this->sendViaSmtp($data);
    }

    private function sendViaApi(array $data): bool
    {
        if (trim((string)$this->apiKey) === '') {
            return false;
        }

        $ch = curl_init($this->apiUrl);

        // Mailtrap Sending API requires Bearer auth (not Api-Token). Wrong/missing auth often returns
        // HTTP 403 with a Cloudflare "Just a moment..." HTML challenge page instead of JSON.
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Accept: application/json',
            'Authorization: Bearer ' . $this->apiKey,
        ]);

        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);

        $response = curl_exec($ch);
        $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);

        curl_close($ch);

        if ($httpCode >= 200 && $httpCode < 300) {
            return true;
        }

        $snippet = is_string($response) ? substr($response, 0, 500) : '';
        if ($httpCode === 403 && is_string($response) && strpos($response, 'Just a moment') !== false) {
            error_log(
                'Mailtrap API returned 403 (Cloudflare challenge HTML). Usually: wrong MAILTRAP_API_KEY, ' .
                'or using a Testing/Sandbox token instead of an Email Sending API token. ' .
                'Configure MAILTRAP_SMTP_USER/PASS for SMTP fallback (MAIL_TRANSPORT=auto). ' .
                'Snippet: ' . $snippet
            );
        } else {
            error_log("Mailtrap API Error ({$httpCode}): " . $snippet);
        }
        if ($error !== '') {
            error_log('Mailtrap cURL: ' . $error);
        }

        return false;
    }

    private function sendViaSmtp(array $data): bool
    {
        if (!$this->smtpConfigured()) {
            return false;
        }

        $toList = $data['to'] ?? [];
        if (!is_array($toList) || !isset($toList[0]['email']) || trim((string)$toList[0]['email']) === '') {
            return false;
        }

        try {
            $mail = new PHPMailer(true);
            $mail->isSMTP();
            $mail->Host = env('MAILTRAP_SMTP_HOST', 'live.smtp.mailtrap.io');
            $mail->SMTPAuth = true;
            $mail->Username = env('MAILTRAP_SMTP_USER');
            $mail->Password = env('MAILTRAP_SMTP_PASS');

            $enc = strtolower(trim((string)env('MAILTRAP_SMTP_ENCRYPTION', 'tls')));
            if ($enc === 'ssl' || $enc === 'smtps') {
                $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
            } elseif ($enc === 'none' || $enc === '') {
                $mail->SMTPSecure = false;
                $mail->SMTPAutoTLS = false;
            } else {
                $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            }

            $defaultPort = ($enc === 'ssl' || $enc === 'smtps') ? 465 : 587;
            $mail->Port = (int)env('MAILTRAP_SMTP_PORT', (string)$defaultPort);

            $mail->CharSet = PHPMailer::CHARSET_UTF8;

            $from = $data['from'] ?? [];
            $fromEmail = trim((string)($from['email'] ?? $this->fromEmail));
            $fromName = trim((string)($from['name'] ?? $this->fromName));
            $mail->setFrom($fromEmail, $fromName);

            foreach ($toList as $recipient) {
                $email = trim((string)($recipient['email'] ?? ''));
                if ($email !== '') {
                    $mail->addAddress($email, (string)($recipient['name'] ?? ''));
                }
            }

            $mail->Subject = (string)($data['subject'] ?? '');
            $mail->isHTML(true);
            $html = (string)($data['html'] ?? '');
            $mail->Body = $html;
            $text = isset($data['text']) ? (string)$data['text'] : '';
            $mail->AltBody = $text !== ''
                ? $text
                : strip_tags(str_replace(['<br>', '<br/>', '<br />'], "\n", $html));

            $mail->send();
            return true;
        } catch (PhpMailerException $e) {
            error_log('Mailtrap SMTP error: ' . $e->getMessage());
            return false;
        }
    }
}

