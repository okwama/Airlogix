<?php


ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once "db_connect.php";

if ($_SERVER["REQUEST_METHOD"] == "POST") {

    $name = trim($_POST['name']);
    $email = trim($_POST['email']);
    $reason = trim($_POST['reason']);

    if (empty($name) || empty($email)) {
        die("All required fields must be filled.");
    }

    // 1️⃣ Check if user exists
    $stmt = $conn->prepare("SELECT id FROM airline_users WHERE email = ? AND deletion_status = 'active'");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows == 0) {
        die("No active account found with this email.");
    }

    $user = $result->fetch_assoc();
    $user_id = $user['id'];
    $stmt->close();

    // 2️⃣ Insert deletion request
    $stmt = $conn->prepare("INSERT INTO account_deletion_requests (user_id, full_name, email, reason) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("isss", $user_id, $name, $email, $reason);
    
    if (!$stmt->execute()) {
        die("Error submitting request.");
    }
    $stmt->close();

    // 3️⃣ Mark user as pending deletion
    $stmt = $conn->prepare("UPDATE airline_users SET deletion_status = 'pending' WHERE id = ?");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $stmt->close();

    $conn->close();

    echo "
    <h2>Request Submitted Successfully</h2>
    <p>Your account is now marked for deletion.</p>
    <p>You will receive confirmation within 3–7 working days.</p>
    ";
}
?>