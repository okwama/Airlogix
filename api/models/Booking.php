<?php
require_once __DIR__ . '/../config.php';

class Booking {
    private $conn;
    private $table_name = "bookings";
    private $columnCache = [];

    public function __construct($db) {
        $this->conn = $db;
    }

    private function hasColumn(string $column): bool
    {
        if (array_key_exists($column, $this->columnCache)) {
            return $this->columnCache[$column];
        }

        $stmt = $this->conn->prepare("
            SELECT 1
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = :table_name
              AND COLUMN_NAME = :column_name
            LIMIT 1
        ");
        $stmt->execute([
            ':table_name' => $this->table_name,
            ':column_name' => $column
        ]);
        $this->columnCache[$column] = (bool)$stmt->fetch(PDO::FETCH_ASSOC);
        return $this->columnCache[$column];
    }

    public function getReservationHoldMinutes(): int
    {
        $minutes = (int)env('BOOKING_HOLD_MINUTES', 30);
        return $minutes > 0 ? $minutes : 30;
    }

    public function reservationExpiresAt(?string $from = null): string
    {
        $base = $from ? strtotime($from) : time();
        return date('Y-m-d H:i:s', strtotime('+' . $this->getReservationHoldMinutes() . ' minutes', $base));
    }

    public function isReservationExpired(array $booking): bool
    {
        $paymentStatus = strtolower((string)($booking['payment_status'] ?? 'pending'));
        if ($paymentStatus === 'paid' || $paymentStatus === 'completed') {
            return false;
        }

        if (!empty($booking['expired_at'])) {
            return true;
        }

        $expiresAt = $booking['reservation_expires_at'] ?? null;
        if (empty($expiresAt)) {
            return false;
        }

        return strtotime((string)$expiresAt) <= time();
    }

    public function create($data) {
        // Generate unique 6-character alphanumeric booking reference (IATA style)
        $ref = strtoupper(substr(str_shuffle("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"), 0, 6));

        $columns = [
            'booking_reference' => ':ref',
            'flight_series_id' => ':flight_id',
            'cabin_class_id' => ':cabin_class_id',
            'passenger_id' => ':passenger_id',
            'passenger_name' => ':passenger_name',
            'passenger_email' => ':passenger_email',
            'passenger_phone' => ':passenger_phone',
            'passenger_type' => ':passenger_type',
            'number_of_passengers' => ':num_passengers',
            'fare_per_passenger' => ':fare_per_passenger',
            'total_amount' => ':total_amount',
            'payment_method' => ':payment_method',
            'payment_status' => ':payment_status',
            'booking_date' => ':booking_date',
            'notes' => ':notes',
            'user_id' => ':user_id'
        ];

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
            ':payment_status' => 'pending',
            ':booking_date' => $data['booking_date'] ?? date('Y-m-d'),
            ':notes' => $data['notes'] ?? null,
            ':user_id' => $data['user_id'] ?? null
        ];

        if ($this->hasColumn('reservation_expires_at')) {
            $columns['reservation_expires_at'] = ':reservation_expires_at';
            $params[':reservation_expires_at'] = $data['reservation_expires_at'] ?? $this->reservationExpiresAt();
        }
        if ($this->hasColumn('expired_at')) {
            $columns['expired_at'] = ':expired_at';
            $params[':expired_at'] = null;
        }

        $query = "INSERT INTO " . $this->table_name . " (" . implode(', ', array_keys($columns)) . ")
                  VALUES (" . implode(', ', array_values($columns)) . ")";

        $stmt = $this->conn->prepare($query);

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
                  LEFT JOIN flight_series fs ON b.flight_series_id = fs.id
                  LEFT JOIN destinations d1 ON fs.from_destination_id = d1.id
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
                  LEFT JOIN flight_series fs ON b.flight_series_id = fs.id
                  LEFT JOIN destinations d1 ON fs.from_destination_id = d1.id
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

    public function expireBooking(int $bookingId): bool
    {
        $set = [
            "payment_status = 'cancelled'",
            "status = 2",
            "updated_at = NOW()"
        ];

        if ($this->hasColumn('expired_at')) {
            $set[] = "expired_at = NOW()";
        }

        $query = "UPDATE " . $this->table_name . "
                  SET " . implode(', ', $set) . "
                  WHERE id = :id
                  AND payment_status != 'paid'";

        $stmt = $this->conn->prepare($query);
        return $stmt->execute([':id' => $bookingId]);
    }

    public function expireStaleReservations(): int
    {
        if (!$this->hasColumn('reservation_expires_at')) {
            return 0;
        }

        $select = "SELECT id
                   FROM " . $this->table_name . "
                   WHERE LOWER(payment_status) = 'pending'
                   AND reservation_expires_at <= NOW()";

        if ($this->hasColumn('expired_at')) {
            $select .= " AND expired_at IS NULL";
        }

        $stmt = $this->conn->prepare($select);
        $stmt->execute();
        $ids = array_map('intval', array_column($stmt->fetchAll(PDO::FETCH_ASSOC), 'id'));

        $expired = 0;
        foreach ($ids as $id) {
            if ($this->expireBooking($id)) {
                $expired++;
            }
        }

        return $expired;
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
