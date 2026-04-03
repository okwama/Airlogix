<?php
require_once __DIR__ . '/../config.php';

class Passenger {
    private $db;
    
    public function __construct($db) {
        $this->db = $db;
    }
    
    /**
     * Generate a unique 13-digit IATA Ticket Number
     * Format: [3-digit Airline Code 998] + [10-digit Serial]
     */
    private function generateTicketNumber() {
        $prefix = "998";
        
        do {
            // Generate a random 10-digit number
            $serial = "";
            for ($i = 0; $i < 10; $i++) {
                $serial .= random_int(0, 9);
            }
            $ticketNumber = $prefix . $serial; // 13 digits total
            
            // Check if Ticket Number already exists in the pnr column
            $stmt = $this->db->prepare("SELECT id FROM passengers WHERE pnr = ?");
            $stmt->execute([$ticketNumber]);
            $exists = $stmt->fetch();
        } while ($exists);
        
        return $ticketNumber;
    }
    
    /**
     * Create a new passenger
     */
    public function create($data) {
        try {
            $ticketNumber = $this->generateTicketNumber();
            
            $stmt = $this->db->prepare("
                INSERT INTO passengers 
                (pnr, name, email, contact, nationality, identification, age, title, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
            ");
            
            $stmt->execute([
                $ticketNumber,
                $data['name'] ?? '',
                $data['email'] ?? null,
                $data['contact'] ?? null,
                $data['nationality'] ?? null,
                $data['identification'] ?? null,
                $data['age'] ?? null,
                $data['title'] ?? null
            ]);
            
            $passengerId = $this->db->lastInsertId();
            
            return [
                'id' => $passengerId,
                'pnr' => $ticketNumber, // Stored in the legacy 'pnr' column but holds the Ticket Number
                'name' => $data['name'],
                'email' => $data['email'] ?? null,
                'contact' => $data['contact'] ?? null
            ];
        } catch (PDOException $e) {
            error_log("Passenger creation error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Get passenger by PNR
     */
    public function getByPnr($pnr) {
        try {
            $stmt = $this->db->prepare("
                SELECT * FROM passengers WHERE pnr = ?
            ");
            $stmt->execute([$pnr]);
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            error_log("Passenger fetch error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Get passenger by ID
     */
    public function getById($id) {
        try {
            $stmt = $this->db->prepare("
                SELECT * FROM passengers WHERE id = ?
            ");
            $stmt->execute([$id]);
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            error_log("Passenger fetch error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Update passenger booking status (CHECK IN, Boarded, etc.)
     */
    public function updateStatus($id, $status) {
        try {
            $stmt = $this->db->prepare("
                UPDATE passengers 
                SET booking_status = ?, updated_at = NOW()
                WHERE id = ?
            ");
            return $stmt->execute([$status, $id]);
        } catch (PDOException $e) {
            error_log("Passenger status update error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Get passengers by booking ID (via junction table)
     */
    public function getByBookingId($bookingId) {
        try {
            $stmt = $this->db->prepare("
                SELECT 
                    p.*,
                    bp.passenger_type,
                    bp.fare_amount
                FROM passengers p
                INNER JOIN booking_passengers bp ON p.id = bp.passenger_id
                WHERE bp.booking_id = ?
                ORDER BY bp.id ASC
            ");
            $stmt->execute([$bookingId]);
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            error_log("Passengers fetch error: " . $e->getMessage());
            return [];
        }
    }
}
