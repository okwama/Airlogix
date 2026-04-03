<?php
require __DIR__ . '/../api/config.php';
$db = db();
// Check both destinations and iata_codes to see if they are linked
$stmt = $db->query('SELECT d.id, d.code, d.name, c.name as country 
                    FROM destinations d 
                    LEFT JOIN Country c ON d.country_id = c.id 
                    LIMIT 10');
echo "Destinations:\n";
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));

$stmt = $db->query('SELECT * FROM iata_codes LIMIT 5');
echo "\nIATA Codes:\n";
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
?>
