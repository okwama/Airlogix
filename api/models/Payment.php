<?php
require_once __DIR__ . '/../config.php';

class Payment {
    private $conn;
    private $table_name = "payment_transactions";

    public function __construct($db) {
        $this->conn = $db;
    }

    public function initiate($data) {
        $query = "INSERT INTO " . $this->table_name . " 
                 (booking_id, user_id, amount, currency, payment_method, status, created_at) 
                 VALUES (:booking_id, :user_id, :amount, :currency, :method, 'pending', NOW())";

        $stmt = $this->conn->prepare($query);
        
        $params = [
            ':booking_id' => $data['booking_id'],
            ':user_id' => $data['user_id'],
            ':amount' => $data['amount'],
            ':currency' => $data['currency'] ?? 'USD',
            ':method' => $data['payment_method']
        ];

        if ($stmt->execute($params)) {
            return ['status' => true, 'transaction_id' => $this->conn->lastInsertId()];
        }
        return ['status' => false, 'message' => 'Payment initiation failed'];
    }

    public function updateStatus($transaction_id, $status, $external_ref = null, $metadata = null) {
        $query = "UPDATE " . $this->table_name . " 
                  SET status = :status, transaction_id = :ext_ref, metadata = :meta, payment_date = NOW() 
                  WHERE id = :id";
        
        $stmt = $this->conn->prepare($query);
        return $stmt->execute([
            ':status' => $status,
            ':ext_ref' => $external_ref,
            ':meta' => $metadata,
            ':id' => $transaction_id
        ]);
    }

    public function getByBooking($booking_id) {
        $query = "SELECT * FROM " . $this->table_name . " WHERE booking_id = :booking_id ORDER BY created_at DESC";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':booking_id' => $booking_id]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
?>
