<?php
require_once __DIR__ . '/../config.php';

class Destination {
    private $conn;
    private $table_name = "destinations";

    public function __construct($db) {
        $this->conn = $db;
    }

    public function getAll() {
        $query = "SELECT id, code, name as city, destination as name FROM " . $this->table_name . " ORDER BY name ASC";
        try {
            $stmt = $this->conn->prepare($query);
            $stmt->execute();
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), '2006') !== false || strpos($e->getMessage(), 'server has gone away') !== false) {
                $this->conn = db(true);
                $stmt = $this->conn->prepare($query);
                $stmt->execute();
                return $stmt->fetchAll(PDO::FETCH_ASSOC);
            }
            throw $e;
        }
    }
    
    public function search($term) {
        $term = trim((string)$term);
        if ($term === '') {
            return [];
        }

        // Resolve via local destination fields first, and enrich matching through iata_codes
        // by code/city/airport without changing the returned contract (destinations rows).
        $query = "SELECT DISTINCT d.id, d.code, d.name as city, d.destination as name
                  FROM " . $this->table_name . " d
                  LEFT JOIN iata_codes i ON UPPER(i.code) = UPPER(d.code)
                  WHERE d.name LIKE :term_name
                     OR d.code LIKE :term_code
                     OR d.destination LIKE :term_destination
                     OR i.code LIKE :term_iata_code
                     OR i.city LIKE :term_iata_city
                     OR i.airport LIKE :term_iata_airport
                  ORDER BY
                    CASE
                      WHEN UPPER(d.code) = UPPER(:exact_code) THEN 0
                      WHEN UPPER(i.code) = UPPER(:exact_iata_code) THEN 1
                      WHEN d.name LIKE :prefix_name THEN 2
                      ELSE 3
                    END,
                    d.name ASC";
        $stmt = $this->conn->prepare($query);
        $searchTerm = "%{$term}%";
        $prefixTerm = "{$term}%";
        $stmt->bindValue(':term_name', $searchTerm);
        $stmt->bindValue(':term_code', $searchTerm);
        $stmt->bindValue(':term_destination', $searchTerm);
        $stmt->bindValue(':term_iata_code', $searchTerm);
        $stmt->bindValue(':term_iata_city', $searchTerm);
        $stmt->bindValue(':term_iata_airport', $searchTerm);
        $stmt->bindValue(':exact_code', $term);
        $stmt->bindValue(':exact_iata_code', $term);
        $stmt->bindValue(':prefix_name', $prefixTerm);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
?>
