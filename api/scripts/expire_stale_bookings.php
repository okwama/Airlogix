<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/Booking.php';

$db = db();
$bookingModel = new Booking($db);
$expiredCount = $bookingModel->expireStaleReservations();

$timestamp = date('Y-m-d H:i:s');
$message = sprintf("[%s] Expired stale bookings: %d\n", $timestamp, $expiredCount);

if (PHP_SAPI === 'cli') {
    echo $message;
} else {
    header('Content-Type: text/plain; charset=utf-8');
    echo $message;
}
