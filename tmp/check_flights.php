<?php
require 'api/config.php';
$db = db();
$stmt = $db->query('SELECT fs.id, fs.flt, d1.code as origin, d2.code as destination, fs.start_date, fs.end_date FROM flight_series fs JOIN destinations d1 ON fs.from_destination_id = d1.id JOIN destinations d2 ON fs.to_destination_id = d2.id');
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
?>
