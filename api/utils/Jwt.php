<?php
final class Jwt {
    private static function b64url($data) { return rtrim(strtr(base64_encode($data), '+/', '-_'), '='); }
    private static function b64url_dec($data) { return base64_decode(strtr($data, '-_', '+/')); }
    public static function sign(array $payload, string $secret, int $ttlSeconds = 43200): string {
        $header = ['alg'=>'HS256','typ'=>'JWT'];
        $now = time();
        $payload['iat'] = $payload['iat'] ?? $now;
        $payload['exp'] = $payload['exp'] ?? ($now + $ttlSeconds);
        $h = self::b64url(json_encode($header));
        $p = self::b64url(json_encode($payload));
        $sig = hash_hmac('sha256', $h.'.'.$p, $secret, true);
        return $h.'.'.$p.'.'.self::b64url($sig);
    }
    public static function verify(string $jwt, string $secret): ?array {
        $parts = explode('.', $jwt);
        if (count($parts) !== 3) return null;
        [$h, $p, $s] = $parts;
        $sig = self::b64url(hash_hmac('sha256', $h.'.'.$p, $secret, true));
        if (!hash_equals($sig, $s)) return null;
        $payload = json_decode(self::b64url_dec($p), true);
        if (!is_array($payload)) return null;
        if (isset($payload['exp']) && time() >= (int)$payload['exp']) return null;
        return $payload;
    }
}
