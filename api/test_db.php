<?php
require_once __DIR__.'/config.php';

try {
    $pdo = db();
    echo "✅ Successfully connected to database\n";
    
    // Test query to list staff (limit to 5 for testing)
    $stmt = $pdo->query("SELECT id, name, phone_number, business_email AS email, empl_no FROM staff LIMIT 5");
    $staff = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($staff)) {
        echo "ℹ️ No staff found in the database\n";
    } else {
        echo "\nStaff members (first 5):\n";
        foreach ($staff as $member) {
            echo "- ID: {$member['id']}, Name: {$member['name']}, ";
            echo "Phone: {$member['phone_number']}, Email: {$member['email']}, ";
            echo "Employee #: {$member['empl_no']}\n";
        }
    }
    
} catch (PDOException $e) {
    echo "❌ Database connection failed: " . $e->getMessage() . "\n";
    echo "Trying to connect to: mysql://" . env('DB_HOST') . ":" . env('DB_PORT') . "/" . env('DB_DATABASE') . "\n";
}
