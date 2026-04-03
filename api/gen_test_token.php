<?php
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/utils/Jwt.php';

try {
    $db = db();
    $stmt = $db->query("SELECT id, phone_number, email FROM airline_users LIMIT 1");
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        die("No users found in airline_users table. Please register a user first.\n");
    }

    $payload = [
        'user_id' => $user['id'],
        'phone' => $user['phone_number'],
        'email' => $user['email'],
        'role' => 'airline_user',
        'exp' => time() + (60 * 60 * 24) // 1 day
    ];
    
    $secret = env('JWT_SECRET', 'default_secret');
    $token = Jwt::sign($payload, $secret);
    
    echo $token;

} catch (PDOException $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
