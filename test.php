<?php
$pdo = new PDO('mysql:host=localhost;dbname=impulsep_royal', 'root', '');
$stmt = $pdo->query('DESCRIBE destinations');
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
?>
