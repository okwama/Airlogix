<?php

require_once __DIR__ . '/../config.php';

/**
 * Very lightweight file-based cache for read-heavy, rarely-changing
 * endpoints such as destinations, cabin classes, home-content, and
 * currency rates. This can later be swapped for Redis/Memcached.
 */
final class Cache
{
    private static function dir(): string
    {
        $dir = __DIR__ . '/../cache';
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        return $dir;
    }

    private static function path(string $key): string
    {
        // Hash key to keep filenames safe and short
        $hash = hash('sha256', $key);
        return self::dir() . '/' . $hash . '.json';
    }

    /**
     * Store a value in cache with TTL (in seconds).
     *
     * @param string $key
     * @param mixed $value
     * @param int $ttlSeconds
     */
    public static function set(string $key, $value, int $ttlSeconds): void
    {
        if ($ttlSeconds <= 0) {
            return;
        }

        $payload = [
            'expires_at' => time() + $ttlSeconds,
            'value' => $value,
        ];

        file_put_contents(self::path($key), json_encode($payload, JSON_UNESCAPED_UNICODE));
    }

    /**
     * Get a cached value or null if missing/expired.
     *
     * @param string $key
     * @return mixed|null
     */
    public static function get(string $key)
    {
        $file = self::path($key);
        if (!is_readable($file)) {
            return null;
        }

        $raw = file_get_contents($file);
        if ($raw === false) {
            return null;
        }

        $data = json_decode($raw, true);
        if (!is_array($data) || !isset($data['expires_at'])) {
            return null;
        }

        if (time() >= (int)$data['expires_at']) {
            @unlink($file);
            return null;
        }

        return $data['value'] ?? null;
    }

    public static function delete(string $key): void
    {
        $file = self::path($key);
        if (is_file($file)) {
            @unlink($file);
        }
    }
}

