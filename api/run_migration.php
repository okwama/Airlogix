<?php
require_once __DIR__ . '/config.php';

try {
    $db = db();
    $sql = file_get_contents(__DIR__ . '/migrations/alter_airline_users_password_reset.sql');
    
    if (!$sql) {
        die("Could not read migration file.\n");
    }

    echo "Executing migration...\n";
    $db->exec($sql);
    echo "Migration successful!\n";

} catch (PDOException $e) {
    if (strpos($e->getMessage(), "Duplicate column name") !== false) {
        echo "Column already exists. Skipping.\n";
    } else {
        echo "Migration failed: " . $e->getMessage() . "\n";
        exit(1);
    }
}
