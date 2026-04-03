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
        $query = "SELECT id, code, name as city, destination as name FROM " . $this->table_name . " 
                  WHERE name LIKE :term1 OR code LIKE :term2 OR destination LIKE :term3
                  ORDER BY name ASC";
        $stmt = $this->conn->prepare($query);
        $searchTerm = "%{$term}%";
        $stmt->bindValue(':term1', $searchTerm);
        $stmt->bindValue(':term2', $searchTerm);
        $stmt->bindValue(':term3', $searchTerm);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
?>
