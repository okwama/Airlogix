<?php
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/models/Destination.php';

try {
    $db = db();
    echo "DB Connection successful\n";
    
    $model = new Destination($db);
    $destinations = $model->getAll();
    
    echo "Destinations found: " . count($destinations) . "\n";
    print_r($destinations[0] ?? "No destinations");
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    echo $e->getTraceAsString();
}
?>
