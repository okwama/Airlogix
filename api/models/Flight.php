<?php
require_once __DIR__ . '/../config.php';

class Flight {
    private $conn;
    private $table_name = "flight_series";
    private $bookingHasReservationExpiry;

    public function __construct($db) {
        $this->conn = $db;
    }

    public function search($from_city, $to_city, $date) {
        $query = "SELECT fs.*, 
                         d1.name as departure_city, d1.code as departure_code,
                         d2.name as arrival_city, d2.code as arrival_code,
                         a.name as aircraft_name
                  FROM " . $this->table_name . " fs
                  LEFT JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  LEFT JOIN aircrafts a ON fs.aircraft_id = a.id
                  WHERE (d1.name LIKE :from1 OR d1.code LIKE :from2 OR d1.destination LIKE :from3)
                  AND (d2.name LIKE :to1 OR d2.code LIKE :to2 OR d2.destination LIKE :to3)
                  AND :date BETWEEN fs.start_date AND fs.end_date
                  AND :date >= CURDATE()
                  AND fs.adult_fare IS NOT NULL
                  AND fs.adult_fare > 0";

        $from_term = "%{$from_city}%";
        $to_term = "%{$to_city}%";

        try {
            $stmt = $this->conn->prepare($query);
            
            $stmt->bindValue(':from1', $from_term);
            $stmt->bindValue(':from2', $from_term);
            $stmt->bindValue(':from3', $from_term);
            $stmt->bindValue(':to1', $to_term);
            $stmt->bindValue(':to2', $to_term);
            $stmt->bindValue(':to3', $to_term);
            $stmt->bindValue(':date', $date);
            
            $stmt->execute();
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), '2006') !== false || strpos($e->getMessage(), 'server has gone away') !== false) {
                $this->conn = db(true);
                $stmt = $this->conn->prepare($query);
                
                $stmt->bindValue(':from1', $from_term);
                $stmt->bindValue(':from2', $from_term);
                $stmt->bindValue(':from3', $from_term);
                $stmt->bindValue(':to1', $to_term);
                $stmt->bindValue(':to2', $to_term);
                $stmt->bindValue(':to3', $to_term);
                $stmt->bindValue(':date', $date);
                
                $stmt->execute();
                return $stmt->fetchAll(PDO::FETCH_ASSOC);
            }
            throw $e;
        }
    }
    
    // Optimized search using destination IDs (avoids expensive LIKE on joined tables)
    public function searchByIds($fromIds, $toIds, $date) {
        // Build IN clause placeholders
        $fromPlaceholders = implode(',', array_fill(0, count($fromIds), '?'));
        $toPlaceholders = implode(',', array_fill(0, count($toIds), '?'));
        
        $query = "SELECT fs.*, 
                         d1.name as departure_city, d1.code as departure_code,
                         d2.name as arrival_city, d2.code as arrival_code,
                         a.name as aircraft_name
                  FROM " . $this->table_name . " fs
                  LEFT JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  LEFT JOIN aircrafts a ON fs.aircraft_id = a.id
                  WHERE fs.from_destination_id IN ($fromPlaceholders)
                  AND fs.to_destination_id IN ($toPlaceholders)
                  AND ? BETWEEN fs.start_date AND fs.end_date
                  AND ? >= CURDATE()
                  AND fs.adult_fare IS NOT NULL
                  AND fs.adult_fare > 0";

        // Prepare parameters before try block
        $params = array_merge($fromIds, $toIds, [$date, $date]);
        
        try {
            $stmt = $this->conn->prepare($query);
            $stmt->execute($params);
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), '2006') !== false || strpos($e->getMessage(), 'server has gone away') !== false) {
                $this->conn = db(true);
                $stmt = $this->conn->prepare($query);
                $stmt->execute($params);
                return $stmt->fetchAll(PDO::FETCH_ASSOC);
            }
            throw $e;
        }
    }

    /**
     * Search for related flights when original search fails.
     * Tier 1: Search same route within +/- 3 days.
     * Tier 2: Search nearby airports (same country) on requested date.
     */
    public function searchRelated(array $fromIds, array $toIds, string $date): array {
        $suggestions = [];

        // Tier 1: Date Expansion (+/- 3 days)
        try {
            $dateObj = new DateTime($date);
            for ($i = 1; $i <= 3; $i++) {
                foreach ([-$i, $i] as $offset) {
                    $targetDate = (clone $dateObj)->modify("$offset days")->format('Y-m-d');
                    $flights = $this->searchByIds($fromIds, $toIds, $targetDate);
                    foreach ($flights as $f) {
                        $f['suggestion_type'] = 'date';
                        $f['suggestion_label'] = "Available on ".date('M d, Y', strtotime($targetDate));
                        $suggestions[] = $f;
                    }
                    if (count($suggestions) >= 4) break 2;
                }
            }
        } catch (Exception $e) { /* ignore date parse errors */ }

        if (count($suggestions) > 0) return $suggestions;

        // Tier 2: Nearby Airports (Same Country)
        try {
            $nearbyFromIds = $this->getNearbyDestinationIds($fromIds);
            $nearbyToIds = $this->getNearbyDestinationIds($toIds);

            // Avoid re-searching the same exact pair if they are unique
            if ($nearbyFromIds !== $fromIds || $nearbyToIds !== $toIds) {
                $flights = $this->searchByIds($nearbyFromIds, $nearbyToIds, $date);
                foreach ($flights as $f) {
                    $f['suggestion_type'] = 'airport';
                    $f['suggestion_label'] = "Nearby alternative";
                    $suggestions[] = $f;
                }
            }
        } catch (Exception $e) { /* ignore */ }

        return $suggestions;
    }

    private function getNearbyDestinationIds(array $ids): array {
        if (empty($ids)) return [];
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        
        // Find other destinations in the same country
        $query = "SELECT id FROM destinations 
                  WHERE country_id IN (SELECT country_id FROM destinations WHERE id IN ($placeholders))
                  AND status = 'active'";
        
        $stmt = $this->conn->prepare($query);
        $stmt->execute($ids);
        return array_column($stmt->fetchAll(PDO::FETCH_ASSOC), 'id');
    }

    public function getById($id) {
        $query = "SELECT 
                    fs.id, fs.flt as flight_number, 
                    fs.std as departure_time, fs.sta as arrival_time,
                    fs.adult_fare, fs.child_fare, fs.infant_fare,
                    fs.number_of_seats, fs.flight_type,
                    fs.from_destination_id, fs.to_destination_id, fs.via_destination_id,
                    d1.name as departure_city, d1.code as departure_code,
                    d2.name as arrival_city, d2.code as arrival_code,
                    ac.name as aircraft_name,
                    fs.start_date, fs.end_date
                  FROM " . $this->table_name . " fs
                  JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  LEFT JOIN aircrafts ac ON fs.aircraft_id = ac.id
                  WHERE fs.id = :id";

        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':id', $id);
        $stmt->execute();
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    public function getAll($limit = 50, $offset = 0) {
        $query = "SELECT 
                    fs.id, fs.flt as flight_number,
                    fs.std as departure_time, fs.sta as arrival_time,
                    fs.adult_fare, fs.child_fare, fs.infant_fare,
                    fs.number_of_seats,
                    d1.name as departure_city,
                    d2.name as arrival_city,
                    fs.start_date, fs.end_date
                  FROM " . $this->table_name . " fs
                  JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  ORDER BY fs.start_date DESC
                  LIMIT :limit OFFSET :offset";

        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getAvailableSeats($flight_id, $date) {
        // Get total seats
        $flight = $this->getById($flight_id);
        if (!$flight) return 0;

        $total_seats = $flight['number_of_seats'] ?? 0;

        // Release stale holds before calculating availability so abandoned bookings
        // stop blocking inventory.
        require_once __DIR__ . '/Booking.php';
        $bookingModel = new Booking($this->conn);
        $bookingModel->expireStaleReservations();

        if ($this->bookingHasReservationExpiry === null) {
            $check = $this->conn->query("SHOW COLUMNS FROM bookings LIKE 'reservation_expires_at'");
            $this->bookingHasReservationExpiry = (bool)$check->fetch(PDO::FETCH_ASSOC);
        }

        if ($this->bookingHasReservationExpiry) {
            $query = "SELECT COALESCE(SUM(number_of_passengers), 0) as booked_seats
                      FROM bookings
                      WHERE flight_series_id = :flight_id
                      AND booking_date = :date
                      AND (
                        LOWER(payment_status) = 'paid'
                        OR (
                            LOWER(payment_status) = 'pending'
                            AND (
                                reservation_expires_at IS NULL
                                OR reservation_expires_at > NOW()
                            )
                        )
                      )";
        } else {
            $query = "SELECT COALESCE(SUM(number_of_passengers), 0) as booked_seats
                      FROM bookings
                      WHERE flight_series_id = :flight_id
                      AND booking_date = :date
                      AND payment_status != 'cancelled'";
        }

        $stmt = $this->conn->prepare($query);
        $stmt->execute([
            ':flight_id' => $flight_id,
            ':date' => $date
        ]);
        
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $booked_seats = $result['booked_seats'] ?? 0;

        return max(0, $total_seats - $booked_seats);
    }
    public function searchStatus($flight_number = null, $from_id = null, $to_id = null, $date = null) {
        $query = "SELECT fs.*, 
                         d1.name as departure_city, d1.code as departure_code,
                         d2.name as arrival_city, d2.code as arrival_code,
                         a.name as aircraft_name
                  FROM " . $this->table_name . " fs
                  LEFT JOIN destinations d1 ON fs.from_destination_id = d1.id
                  LEFT JOIN destinations d2 ON fs.to_destination_id = d2.id
                  LEFT JOIN aircrafts a ON fs.aircraft_id = a.id
                  WHERE 1=1";
        
        $params = [];
        
        if ($flight_number) {
            $query .= " AND fs.flt LIKE :flt";
            $params[':flt'] = "%{$flight_number}%";
        }
        
        if ($from_id) {
            $query .= " AND fs.from_destination_id = :from_id";
            $params[':from_id'] = $from_id;
        }
        
        if ($to_id) {
            $query .= " AND fs.to_destination_id = :to_id";
            $params[':to_id'] = $to_id;
        }
        
        if ($date) {
            $query .= " AND :date BETWEEN fs.start_date AND fs.end_date";
            // Optional: for general status searches, they might want past flights, but for booking they don't.
            // searchStatus is likely used in admin/status pages so we leave >= CURDATE() out, or add it conditionally.
            // The request was specifically about "when searching for a flight if a flight is in the past it should not be found".
            $params[':date'] = $date;
        } else {
            $query .= " AND CURDATE() BETWEEN fs.start_date AND fs.end_date";
        }

        $query .= " ORDER BY fs.std ASC";

        try {
            $stmt = $this->conn->prepare($query);
            foreach ($params as $key => $val) {
                $stmt->bindValue($key, $val);
            }
            $stmt->execute();
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), '2006') !== false || strpos($e->getMessage(), 'server has gone away') !== false) {
                $this->conn = db(true);
                $stmt = $this->conn->prepare($query);
                foreach ($params as $key => $val) {
                    $stmt->bindValue($key, $val);
                }
                $stmt->execute();
                return $stmt->fetchAll(PDO::FETCH_ASSOC);
            }
            throw $e;
        }
    }
}
?>
