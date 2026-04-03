<?php
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/models/AirlineUser.php';

// Test Data
$email = "test-" . time() . "@example.com";
$password = "OriginalPassword123!";
$newPassword = "NewSecretPassword456!";

echo "1. Creating test user: $email\n";
$db = db();
$userModel = new AirlineUser($db);

// Register user
$registerData = [
    'phone_number' => '07' . rand(10000000, 99999999), 
    'email' => $email,
    'password' => $password,
    'first_name' => 'Test',
    'last_name' => 'User'
];
$res = $userModel->register($registerData);
if (!$res['status']) {
    die("Failed to register test user: " . $res['message'] . "\n");
}
echo "User registered.\n";

echo "\n2. Generating Reset Code via Model\n";
$code = "123456";
$res = $userModel->savePasswordResetCode($email, $code);
if (!$res['status']) {
    die("Failed to save reset code: " . $res['message'] . "\n");
}
echo "Code saved.\n";

echo "\n3. Verifying Code (Success Case)\n";
$res = $userModel->verifyResetCode($email, $code);
if (!$res['status']) {
    die("Code verification failed: " . $res['message'] . "\n");
}
echo "Code verified.\n";

echo "\n4. Verifying Code (Failure Case - Wrong Code)\n";
$res = $userModel->verifyResetCode($email, "000000");
if ($res['status']) {
    die("Verification should have failed but succeeded!\n");
}
echo "Invalid code correctly rejected.\n";

echo "\n5. Resetting Password\n";
$res = $userModel->resetPasswordWithCode($email, $code, $newPassword);
if (!$res['status']) {
    die("Password reset failed: " . $res['message'] . "\n");
}
echo "Password reset successful.\n";

echo "\n6. Verifying New Login\n";
$res = $userModel->login($email, $newPassword);
if (!$res['status']) {
    die("Login with new password failed: " . $res['message'] . "\n");
}
echo "Login successful! Test complete.\n";
