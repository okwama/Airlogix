<?php
$host = "localhost";
$port = 3306;
$username = "impulsep_bryan";
$password = "@bo9511221.qwerty";
$database = "impulsep_royal";

$conn = new mysqli($host, $username, $password, $database, $port);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

$conn->set_charset("utf8mb4");
?>