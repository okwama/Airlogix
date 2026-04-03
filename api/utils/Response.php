<?php
class Response {
    private static $requestId = null;

    public static function requestId(): string {
        if (self::$requestId === null) {
            try {
                self::$requestId = bin2hex(random_bytes(8));
            } catch (Throwable $e) {
                self::$requestId = (string)uniqid('req_', true);
            }
        }
        return self::$requestId;
    }

    private static function defaultErrorCodeForStatus(int $status): string {
        switch ($status) {
            case 400:
                return 'BAD_REQUEST';
            case 401:
                return 'UNAUTHORIZED';
            case 403:
                return 'FORBIDDEN';
            case 404:
                return 'NOT_FOUND';
            case 409:
                return 'CONFLICT';
            case 422:
                return 'VALIDATION_ERROR';
            case 429:
                return 'RATE_LIMITED';
            case 503:
                return 'SERVICE_UNAVAILABLE';
            default:
                return $status >= 500 ? 'INTERNAL_ERROR' : 'REQUEST_FAILED';
        }
    }

    private static function normalizeErrorPayload($data, int $status): array {
        $payload = is_array($data) ? $data : ['message' => (string)$data];
        $legacyMessage = (string)($payload['message'] ?? $payload['error'] ?? 'Request failed');
        $code = (string)($payload['code'] ?? self::defaultErrorCodeForStatus($status));
        $details = $payload['details'] ?? null;

        $payload['status'] = false;
        $payload['message'] = $legacyMessage;
        $payload['error'] = [
            'code' => $code,
            'message' => $legacyMessage,
            'request_id' => self::requestId()
        ];
        if ($details !== null) {
            $payload['error']['details'] = $details;
        }
        $payload['request_id'] = self::requestId();

        return $payload;
    }

    public static function json($data, int $status = 200): void {
        // Clear any previous output
        if (ob_get_level() > 0) {
            ob_clean();
        }

        if ($status >= 400) {
            $data = self::normalizeErrorPayload($data, $status);
        } elseif (is_array($data) && !isset($data['request_id'])) {
            $data['request_id'] = self::requestId();
        }

        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        header('X-Request-Id: ' . self::requestId());

        $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json === false) {
            // Fallback if json_encode fails
            http_response_code(500);
            echo json_encode(self::normalizeErrorPayload(['message' => 'Failed to encode response', 'code' => 'ENCODING_ERROR'], 500), JSON_UNESCAPED_UNICODE);
        } else {
            echo $json;
        }
        exit;
    }

    public static function fail(int $status, string $message, string $code = '', $details = null): void {
        $payload = ['message' => $message];
        if ($code !== '') {
            $payload['code'] = $code;
        }
        if ($details !== null) {
            $payload['details'] = $details;
        }
        self::json($payload, $status);
    }

    public static function badRequest($msg) { self::fail(400, (string)$msg, 'BAD_REQUEST'); }
    public static function unauthorized($msg='Unauthorized') { self::fail(401, (string)$msg, 'UNAUTHORIZED'); }
    public static function forbidden($msg='Forbidden') { self::fail(403, (string)$msg, 'FORBIDDEN'); }
    public static function notFound($msg='Not found') { self::fail(404, (string)$msg, 'NOT_FOUND'); }
    public static function error($msg='Internal server error', int $status = 500) { self::fail($status, (string)$msg); }
    public static function conflict($msg='Conflict') { self::fail(409, (string)$msg, 'CONFLICT'); }
}
