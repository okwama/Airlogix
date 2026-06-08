<?php
require_once __DIR__ . '/../config.php';

class CheckIn {
    private $conn;
    private $table_name = "checkins";

    public function __construct($db) {
        $this->conn = $db;
    }

    public function create($data) {
        // Validate 5-hour window logic (can be done in controller or here)
        // Check if seat is available
        
        $query = "INSERT INTO " . $this->table_name . " 
                 (booking_id, booking_passenger_id, flight_series_id, flight_date, seat_number, carry_on_bags, checked_bags, checked_in_at, gate, boarding_time) 
                 VALUES (:booking_id, :passenger_id, :flight_id, :flight_date, :seat, :carry_on, :checked, NOW(), :gate, :boarding_time)";

        $stmt = $this->conn->prepare($query);
        
        // Mock gate and boarding time assignment
        $gate = 'A' . rand(1, 10);
        $boarding_time = date('H:i', strtotime('-45 minutes')); // Mock

        $params = [
            ':booking_id' => $data['booking_id'],
            ':passenger_id' => $data['booking_passenger_id'],
            ':flight_id' => $data['flight_series_id'],
            ':flight_date' => $data['flight_date'],
            ':seat' => $data['seat_number'],
            ':carry_on' => $data['carry_on_bags'] ?? 0,
            ':checked' => $data['checked_bags'] ?? 0,
            ':gate' => $gate,
            ':boarding_time' => $boarding_time
        ];

        if ($stmt->execute($params)) {
            $checkin_id = $this->conn->lastInsertId();
            
            // Update seat status in flight_seats (if we were tracking individual seat inventory strictly)
            // For now, we assume seat selection validation happened before this
            
            // Generate QR Code data
            $qr_data = json_encode([
                'checkin_id' => $checkin_id,
                'booking_ref' => $data['booking_reference'], // Passed from controller
                'seat' => $data['seat_number'],
                'flight' => $data['flight_number'] // Passed from controller
            ]);
            
            $this->updateQrCode($checkin_id, $qr_data);

            return ['status' => true, 'message' => 'Check-in successful', 'checkin_id' => $checkin_id, 'gate' => $gate, 'boarding_time' => $boarding_time, 'qr_code' => $qr_data];
        }

        return ['status' => false, 'message' => 'Check-in failed'];
    }

    private function updateQrCode($id, $qr_data) {
        $query = "UPDATE " . $this->table_name . " SET qr_code_data = :qr WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':qr' => $qr_data, ':id' => $id]);
    }

    public function getByBooking($booking_id) {
        $query = "SELECT * FROM " . $this->table_name . " WHERE booking_id = :booking_id";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':booking_id' => $booking_id]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
?>
