<?php
require_once __DIR__ . '/../config.php';

class Observability
{
    /**
     * Write a structured lifecycle event as JSON line.
     * Intended for booking/payment/ticket/document milestones.
     */
    public static function event(string $event, array $data = []): void
    {
        $payload = array_merge($data, [
            'event' => $event,
            'occurred_at' => date('Y-m-d H:i:s'),
            'request_id' => self::requestId()
        ]);

        $logDir = __DIR__ . '/../logs';
        if (!is_dir($logDir)) {
            @mkdir($logDir, 0755, true);
        }

        $line = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($line === false) {
            $line = json_encode([
                'event' => 'observability.encode_failed',
                'occurred_at' => date('Y-m-d H:i:s'),
                'request_id' => self::requestId()
            ]);
        }

        @file_put_contents(
            $logDir . '/booking_lifecycle_' . date('Y-m-d') . '.log',
            $line . PHP_EOL,
            FILE_APPEND
        );
    }

    public static function sanitiseError(Throwable $e): string
    {
        $class = get_class($e);
        $msg = $e->getMessage();

        // Database errors often include SQL and schema details — redact them
        if (stripos($class, 'PDOException') !== false || stripos($msg, 'SQLSTATE') !== false || preg_match('/SELECT|INSERT|UPDATE|DELETE|FROM|JOIN/i', $msg)) {
            return "Database error during operation ({$class})";
        }

        // Remove file paths and limit length
        $sanitised = preg_replace('/\/[A-Za-z0-9_\-\.\/\\]+/', '', $msg);
        $sanitised = preg_replace('/\s+\bline\b\s*\d+/i', '', $sanitised);
        $sanitised = trim($sanitised);
        if (strlen($sanitised) > 200) {
            $sanitised = substr($sanitised, 0, 197) . '...';
        }
        return $sanitised . ' (' . $class . ')';
    }

    private static function requestId(): string
    {
        if (class_exists('Response') && method_exists('Response', 'requestId')) {
            return (string)Response::requestId();
        }

        $headerReqId = $_SERVER['HTTP_X_REQUEST_ID'] ?? '';
        if (is_string($headerReqId) && trim($headerReqId) !== '') {
            return trim($headerReqId);
        }

        try {
            return bin2hex(random_bytes(8));
        } catch (Throwable $e) {
            return (string)uniqid('req_', true);
        }
    }
}

