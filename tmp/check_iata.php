<?php
require 'api/config.php';
$db = db();
$stmt = $db->query('SELECT * FROM iata_codes LIMIT 10');
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
?>
