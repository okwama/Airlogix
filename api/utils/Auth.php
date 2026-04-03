<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/AirlineUser.php';
require_once __DIR__ . '/Response.php';

/**
 * Centralized authentication / authorization helpers.
 * Traveler app should only ever operate as a "traveler" role.
 */
final class Auth
{
    /**
     * Ensure JWT_SECRET is configured and not the unsafe default.
     * Call this once very early in the request lifecycle.
     */
    public static function assertJwtConfigured(): void
    {
        $secret = env('JWT_SECRET', null);
        if (empty($secret) || $secret === 'default_secret') {
            // Fail fast with generic error to client, but log details server-side.
            error_log('Critical misconfiguration: JWT_SECRET is missing or using default_secret');
            Response::error('Service configuration error', 500);
        }
    }

    /**
     * Extract Bearer token from Authorization header (case-insensitive).
     */
    public static function bearerToken(): ?string
    {
        $headers = function_exists('apache_request_headers')
            ? apache_request_headers()
            : (function_exists('getallheaders') ? getallheaders() : []);

        $auth = $headers['Authorization'] ?? $headers['authorization'] ?? null;
        if (!$auth || stripos($auth, 'Bearer ') !== 0) {
            return null;
        }
        return trim(substr($auth, 7));
    }

    /**
     * Require an authenticated traveler and return the user_id.
     * On failure, responds with 401 and exits.
     */
    public static function requireTravelerId(PDO $db): int
    {
        self::assertJwtConfigured();

        $token = self::bearerToken();
        if (!$token) {
            Response::unauthorized('Missing bearer token');
        }

        $userModel = new AirlineUser($db);
        $userId = $userModel->validateToken($token);

        if (!$userId) {
            Response::unauthorized('Invalid or expired token');
        }

        return (int)$userId;
    }

    /**
     * Guard an endpoint that should only be callable by internal systems
     * (cron, admin panel, etc.), never directly from the traveler app.
     *
     * For now we use a simple shared key; can later evolve to IP allowlists
     * or mTLS depending on infrastructure.
     */
    public static function requireInternalKey(): void
    {
        $expected = env('INTERNAL_API_KEY', null);
        if (empty($expected)) {
            // If not configured, log loudly and block by default.
            error_log('INTERNAL_API_KEY is not configured; blocking internal-only endpoint');
            Response::unauthorized('Endpoint not available');
        }

        $headers = function_exists('getallheaders') ? getallheaders() : [];
        $provided = $headers['X-Internal-Key'] ?? $headers['x-internal-key'] ?? null;

        if (!$provided || !hash_equals($expected, $provided)) {
            Response::unauthorized('Unauthorized internal call');
        }
    }
}

