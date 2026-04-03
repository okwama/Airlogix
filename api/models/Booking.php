<?php
require_once __DIR__ . '/../config.php';

class Booking {
    private $conn;
    private $table_name = "bookings";

    public function __construct($db) {
        $this->conn = $db;
    }

    public function create($data) {
        $query = "INSERT INTO " . $this->table_name . " 
                 (booking_reference, flight_series_id, cabin_class_id, passenger_id, passenger_name, passenger_email, passenger_phone, 
                  passenger_type, number_of_passengers, fare_per_passenger, total_amount, payment_method, 
                  payment_status, booking_date, notes, user_id) 
                 VALUES (:ref, :flight_id, :cabin_class_id, :passenger_id, :passenger_name, :passenger_email, :passenger_phone, 
                          :passenger_type, :num_passengers, :fare_per_passenger, :total_amount, :payment_method, 
                          'pending', :booking_date, :notes, :user_id)";

        $stmt = $this->conn->prepare($query);
        
        // Generate unique 6-character alphanumeric booking reference (IATA style)
        $ref = strtoupper(substr(str_shuffle("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"), 0, 6));

        $params = [
            ':ref' => $ref,
            ':flight_id' => $data['flight_series_id'],
            ':cabin_class_id' => $data['cabin_class_id'] ?? null,
            ':passenger_id' => $data['passenger_id'] ?? null,
            ':passenger_name' => $data['passenger_name'],
            ':passenger_email' => $data['passenger_email'] ?? null,
            ':passenger_phone' => $data['passenger_phone'] ?? null,
            ':passenger_type' => $data['passenger_type'] ?? 'adult',
            ':num_passengers' => $data['number_of_passengers'] ?? 1,
            ':fare_per_passenger' => $data['fare_per_passenger'],
            ':total_amount' => $data['total_amount'],
            ':payment_method' => $data['payment_method'] ?? 'cash',
            ':booking_date' => $data['booking_date'] ?? date('Y-m-d'),
            ':notes' => $data['notes'] ?? null,
            ':user_id' => $data['user_id'] ?? null
        ];

        if ($stmt->execute($params)) {
            $booking_id = $this->conn->lastInsertId();
            
            // Add additional passengers if provided
            if (!empty($data['passengers']) && is_array($data['passengers'])) {
                $this->addPassengers($booking_id, $data['passengers']);
            }

            return [
                'status' => true, 
                'message' => 'Booking created successfully', 
                'booking_id' => $booking_id, 
                'reference' => $ref,
                'data' => $this->getById($booking_id)
            ];
        }

        return ['status' => false, 'message' => 'Booking creation failed'];
    }

    private function addPassengers($booking_id, $passengers) {
        $query = "INSERT INTO booking_passengers (booking_id, passenger_id, passenger_type, fare_amount) 
                  VALUES (:booking_id, :passenger_id, :passenger_type, :fare_amount)";
        $stmt = $this->conn->prepare($query);

        foreach ($passengers as $p) {
            $stmt->execute([
                ':booking_id' => $booking_id,
                ':passenger_id' => $p['passenger_id'],
                ':passenger_type' => $p['passenger_type'] ?? 'adult',
                ':fare_amount' => $p['fare_amount']
            ]);
        }
    }

    public function getById($id) {
        $query = "SELECT b.*, fs.flt as flight_number, 
                         d1.name as from_city, d1.code as from_code,
                         d2.name as to_city, d2.code as to_code,
                         fs.std as departure_time, fs.sta as arrival_time,
                         ac.name as aircraft_name,
                         cc.name as cabin_name, cc.baggage_allowance_kg, cc.meal_service
                  FROM " . $this->table_name . " b
                  JOIN flight_series fs ON b.flight_series_id = fs.id
                  JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  LEFT JOIN aircrafts ac ON fs.aircraft_id = ac.id
                  LEFT JOIN cabin_classes cc ON b.cabin_class_id = cc.id
                  WHERE b.id = :id";

        $stmt = $this->conn->prepare($query);
        $stmt->execute([':id' => $id]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    public function getByPassenger($passenger_id) {
        $query = "SELECT b.*, fs.flt as flight_number, 
                         d1.name as from_city, d1.code as from_code,
                         d2.name as to_city, d2.code as to_code,
                         fs.std as departure_time, fs.sta as arrival_time
                  FROM " . $this->table_name . " b
                  JOIN flight_series fs ON b.flight_series_id = fs.id
                  JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  WHERE b.passenger_id = :passenger_id
                  ORDER BY b.created_at DESC";

        $stmt = $this->conn->prepare($query);
        $stmt->execute([':passenger_id' => $passenger_id]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getByReference($reference) {
        $query = "SELECT b.*, fs.flt as flight_number, 
                         d1.name as from_city, d1.code as from_code,
                         d2.name as to_city, d2.code as to_code,
                         fs.std as departure_time, fs.sta as arrival_time
                  FROM " . $this->table_name . " b
                  JOIN flight_series fs ON b.flight_series_id = fs.id
                  JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  WHERE b.booking_reference = :ref";
        
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':ref' => $reference]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    public function updatePaymentStatus($booking_id, $status, $method = null) {
        $query = "UPDATE " . $this->table_name . " 
                  SET payment_status = :status, payment_method = :method, updated_at = NOW()
                  WHERE id = :id";
        
        $stmt = $this->conn->prepare($query);
        return $stmt->execute([
            ':status' => $status,
            ':method' => $method,
            ':id' => $booking_id
        ]);
    }

    public function getAll($limit = 50, $offset = 0) {
        $query = "SELECT b.*, fs.flt as flight_number, 
                         d1.name as from_city, d2.name as to_city
                  FROM " . $this->table_name . " b
                  JOIN flight_series fs ON b.flight_series_id = fs.id
                  JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  ORDER BY b.created_at DESC
                  LIMIT :limit OFFSET :offset";

        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    public function getByUserId($userId) {
        $query = "SELECT b.*, 
                        fs.flt as flight_number,
                        fs.std as departure_time,
                        fs.sta as arrival_time,
                        d1.name as from_city,
                        d1.code as from_code,
                        d2.name as to_city,
                        d2.code as to_code
                  FROM " . $this->table_name . " b
                  LEFT JOIN flight_series fs ON b.flight_series_id = fs.id
                  LEFT JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  WHERE b.user_id = :user_id
                  ORDER BY b.booking_date DESC, b.created_at DESC";
        
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
?>
