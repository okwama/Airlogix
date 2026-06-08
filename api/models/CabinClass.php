<?php
class CabinClass {
    private $conn;
    private $table_name = "cabin_classes";

    public $id;
    public $name;
    public $subtitle;
    public $base_price;
    public $baggage_allowance_kg;
    public $cabin_baggage_kg;
    public $priority_boarding;
    public $lounge_access;
    public $extra_legroom;
    public $meal_service;
    public $wifi_included;

    public function __construct($db) {
        $this->conn = $db;
    }

    public function getAll() {
        $query = "SELECT * FROM " . $this->table_name . " ORDER BY id ASC";
        $stmt = $this->conn->prepare($query);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
?>
