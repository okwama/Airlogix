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

    public function findByGatewayReference(string $gatewayReference, ?string $paymentMethod = null) {
        $gatewayReference = trim($gatewayReference);
        if ($gatewayReference === '') {
            return null;
        }

        $method = strtolower(trim((string)$paymentMethod));
        if ($method !== '') {
            $query = "SELECT * FROM " . $this->table_name . "
                      WHERE transaction_id = :ref
                        AND LOWER(payment_method) = :method
                      ORDER BY id DESC
                      LIMIT 1";
            $stmt = $this->conn->prepare($query);
            $stmt->execute([
                ':ref' => $gatewayReference,
                ':method' => $method
            ]);
        } else {
            $query = "SELECT * FROM " . $this->table_name . "
                      WHERE transaction_id = :ref OR payment_reference = :ref
                      ORDER BY id DESC
                      LIMIT 1";
            $stmt = $this->conn->prepare($query);
            $stmt->execute([':ref' => $gatewayReference]);
        }
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row ?: null;
    }

    public function createGatewayTrace(array $data) {
        $query = "INSERT INTO " . $this->table_name . "
                 (booking_id, user_id, amount, currency, payment_method, payment_reference, transaction_id, status, metadata, payment_date, created_at)
                 VALUES (:booking_id, :user_id, :amount, :currency, :method, :payment_reference, :transaction_id, :status, :meta, :payment_date, NOW())
                 ON DUPLICATE KEY UPDATE
                    id = LAST_INSERT_ID(id),
                    booking_id = VALUES(booking_id),
                    user_id = COALESCE(VALUES(user_id), user_id),
                    amount = VALUES(amount),
                    currency = VALUES(currency),
                    payment_method = VALUES(payment_method),
                    payment_reference = COALESCE(VALUES(payment_reference), payment_reference),
                    status = CASE WHEN status = 'completed' THEN status ELSE VALUES(status) END,
                    metadata = COALESCE(VALUES(metadata), metadata),
                    payment_date = COALESCE(VALUES(payment_date), payment_date),
                    updated_at = NOW()";

        $stmt = $this->conn->prepare($query);
        try {
            $ok = $stmt->execute([
                ':booking_id' => $data['booking_id'],
                ':user_id' => $data['user_id'] ?? null,
                ':amount' => $data['amount'],
                ':currency' => $data['currency'] ?? 'USD',
                ':method' => $data['payment_method'],
                ':payment_reference' => $data['payment_reference'] ?? null,
                ':transaction_id' => $data['transaction_id'] ?? null,
                ':status' => $data['status'] ?? 'pending',
                ':meta' => $data['metadata'] ?? null,
                ':payment_date' => $data['payment_date'] ?? null
            ]);

            if ($ok) {
                return ['status' => true, 'transaction_id' => (int)$this->conn->lastInsertId()];
            }
            return ['status' => false, 'message' => 'Failed to create gateway trace'];
        } catch (\PDOException $e) {
            // Catch Integrity Constraint Violation (23000) e.g., duplicate webhook
            if ($e->getCode() == 23000) {
                error_log("PaymentTrace: Duplicate trace detected for transaction_id=" . ($data['transaction_id'] ?? 'unknown'));
                // Try to locate the existing trace and return its id so callers can update status
                try {
                    if (!empty($data['transaction_id'])) {
                        $q = "SELECT id FROM " . $this->table_name . " WHERE transaction_id = :tx AND LOWER(payment_method) = LOWER(:method) ORDER BY id DESC LIMIT 1";
                        $s = $this->conn->prepare($q);
                        $s->execute([':tx' => $data['transaction_id'], ':method' => $data['payment_method']]);
                        $r = $s->fetch(PDO::FETCH_ASSOC);
                        if ($r && !empty($r['id'])) {
                            return ['status' => true, 'transaction_id' => (int)$r['id'], 'message' => 'Duplicate resolved'];
                        }
                    }

                    // Fallback: try to find by booking_id + payment_reference + method
                    $q2 = "SELECT id FROM " . $this->table_name . " WHERE booking_id = :booking_id AND LOWER(payment_method) = LOWER(:method) AND (payment_reference = :pref OR transaction_id = :tx) ORDER BY id DESC LIMIT 1";
                    $s2 = $this->conn->prepare($q2);
                    $s2->execute([
                        ':booking_id' => $data['booking_id'],
                        ':method' => $data['payment_method'],
                        ':pref' => $data['payment_reference'] ?? null,
                        ':tx' => $data['transaction_id'] ?? null
                    ]);
                    $r2 = $s2->fetch(PDO::FETCH_ASSOC);
                    if ($r2 && !empty($r2['id'])) {
                        return ['status' => true, 'transaction_id' => (int)$r2['id'], 'message' => 'Duplicate resolved'];
                    }
                } catch (\Throwable $lookupErr) {
                    error_log('PaymentTrace duplicate lookup failed: ' . $lookupErr->getMessage());
                }

                // Return success so the gateway webhook controller doesn't fail if we couldn't find the existing id
                return ['status' => true, 'transaction_id' => null, 'message' => 'Duplicate ignored'];
            }
            error_log("PaymentTrace Error: " . $e->getMessage());
            return ['status' => false, 'message' => 'Database error occurred'];
        }
    }
}
?>
