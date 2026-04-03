<?php
// Set default timezone to East Africa Time (EAT)
date_default_timezone_set('Africa/Nairobi'); // EAT (UTC+3)

// APNS Configuration
if (!defined('APNS_TEAM_ID')) define('APNS_TEAM_ID', 'LV3WK67YPG');
if (!defined('APNS_BUNDLE_ID')) define('APNS_BUNDLE_ID', 'com.cit.airlogix');
if (!defined('APNS_KEY_ID')) define('APNS_KEY_ID', '89W2P7948K');
if (!defined('APNS_KEY_PATH')) define('APNS_KEY_PATH', __DIR__ . '/certs/AuthKey_89W2P7948K.p8');
if (!defined('APNS_PRODUCTION')) define('APNS_PRODUCTION', true); // Set to true for production

function env(string $key, $default=null) {
    static $vars = null;
    if ($vars === null) {
        $vars = [];
        $path = __DIR__.'/.env';
        if (is_readable($path)) {
            foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
                $trimmed = trim($line);
                if ($trimmed === '' || strpos($trimmed, '#') === 0) continue;
                $pos = strpos($line, '=');
                if ($pos === false) continue;
                $k = trim(substr($line, 0, $pos));
                $v = trim(substr($line, $pos+1));
                $vars[$k] = $v;
            }
        }
    }
    return $vars[$key] ?? $default;
}

function db($force_new = false): PDO {
    static $pdo = null;
    if ($pdo && !$force_new) return $pdo;
    $host = env('DB_HOST', '127.0.0.1');
    $port = (int)env('DB_PORT', 3306);
    $db   = env('DB_DATABASE', '');
    $charset = env('DB_CHARSET', 'utf8mb4');
    $connectTimeout = (int)env('DB_CONNECT_TIMEOUT', 20); // Increased default to 20s for remote DB
    $persistent = (bool)env('DB_PERSISTENT', false);
    $dsn = "mysql:host={$host};port={$port};dbname={$db};charset={$charset}";
    $user = env('DB_USERNAME', '');
    $pass = env('DB_PASSWORD', '');
    
    try {
        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_TIMEOUT => $connectTimeout,
            PDO::ATTR_PERSISTENT => $persistent,
            PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
        ]);
        
        $pdo->exec("SET SESSION sql_mode='NO_ENGINE_SUBSTITUTION';");
        // Set MySQL timezone to match PHP timezone (EAT)
        $pdo->exec("SET time_zone = '+03:00';");
        
        return $pdo;
    } catch (PDOException $e) {
        // If connection fails, try one more time after a short pause
        if (strpos($e->getMessage(), '2006') !== false || strpos($e->getMessage(), 'Connection refused') !== false) {
            sleep(1);
            $pdo = new PDO($dsn, $user, $pass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::ATTR_TIMEOUT => $connectTimeout,
                PDO::ATTR_PERSISTENT => $persistent,
            ]);
            return $pdo;
        }
        throw $e;
    }
}

function request_json(): array {
    $raw = file_get_contents('php://input') ?: '';
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function client_ip(): string {
    return $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '';
}
