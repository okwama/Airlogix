<?php
require_once __DIR__ . '/config.php';

try {
    $db = db();
    $stmt = $db->query("DESCRIBE airline_users");
    $columns = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo "Columns in airline_users:\n";
    foreach ($columns as $col) {
        echo "- " . $col . "\n";
    }

} catch (PDOException $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
