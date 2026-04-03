<?php
require_once __DIR__ . '/../config.php';

class BookingPassenger {
    private $db;
    
    public function __construct($db) {
        $this->db = $db;
    }
    
    /**
     * Link a passenger to a booking
     */
    public function create($bookingId, $passengerId, $passengerType, $fareAmount) {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO booking_passengers 
                (booking_id, passenger_id, passenger_type, fare_amount, created_at)
                VALUES (?, ?, ?, ?, NOW())
            ");
            
            $stmt->execute([
                $bookingId,
                $passengerId,
                $passengerType,
                $fareAmount
            ]);
            
            return $this->db->lastInsertId();
        } catch (PDOException $e) {
            error_log("BookingPassenger creation error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Get all passengers for a booking
     */
    public function getByBookingId($bookingId) {
        try {
            $stmt = $this->db->prepare("
                SELECT 
                    bp.*,
                    p.pnr,
                    p.name,
                    p.email,
                    p.contact,
                    p.nationality,
                    p.identification,
                    p.age,
                    p.title,
                    p.booking_status
                FROM booking_passengers bp
                INNER JOIN passengers p ON bp.passenger_id = p.id
                WHERE bp.booking_id = ?
                ORDER BY bp.id ASC
            ");
            
            $stmt->execute([$bookingId]);
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            error_log("BookingPassenger fetch error: " . $e->getMessage());
            return [];
        }
    }
    
    /**
     * Get bookings for a passenger
     */
    public function getByPassengerId($passengerId) {
        try {
            $stmt = $this->db->prepare("
                SELECT 
                    bp.*,
                    b.booking_reference,
                    b.payment_status,
                    b.booking_date
                FROM booking_passengers bp
                INNER JOIN bookings b ON bp.booking_id = b.id
                WHERE bp.passenger_id = ?
                ORDER BY b.booking_date DESC
            ");
            
            $stmt->execute([$passengerId]);
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            error_log("Passenger bookings fetch error: " . $e->getMessage());
            return [];
        }
    }
    
    /**
     * Delete all passenger links for a booking (for cancellation)
     */
    public function deleteByBookingId($bookingId) {
        try {
            $stmt = $this->db->prepare("
                DELETE FROM booking_passengers WHERE booking_id = ?
            ");
            return $stmt->execute([$bookingId]);
        } catch (PDOException $e) {
            error_log("BookingPassenger deletion error: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Update ticket information (Issuance)
     */
    public function updateTicket($id, $ticketNumber, $status = 'OPEN') {
        try {
            $stmt = $this->db->prepare("
                UPDATE booking_passengers 
                SET ticket_number = ?, 
                    ticket_status = ?, 
                    issued_at = NOW() 
                WHERE id = ?
            ");
            return $stmt->execute([$ticketNumber, $status, $id]);
        } catch (PDOException $e) {
            error_log("BookingPassenger ticket update error: " . $e->getMessage());
            return false;
        }
    }
}
