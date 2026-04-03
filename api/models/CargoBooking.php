<?php
require_once __DIR__ . '/../config.php';

class CargoBooking {
    private $conn;
    private $table_name = "cargo_bookings";

    public function __construct($db) {
        $this->conn = $db;
    }

    public function create($data) {
        $query = "INSERT INTO " . $this->table_name . " 
                  (awb_number, flight_series_id, user_id, 
                   shipper_name, shipper_company, shipper_phone, shipper_email, shipper_address,
                   consignee_name, consignee_company, consignee_phone, consignee_email, consignee_address,
                   commodity_type, weight_kg, pieces, volumetric_weight, dimensions_json, declared_value,
                   total_amount, currency, payment_method, booking_date)
                  VALUES 
                  (:awb_number, :flight_series_id, :user_id,
                   :shipper_name, :shipper_company, :shipper_phone, :shipper_email, :shipper_address,
                   :consignee_name, :consignee_company, :consignee_phone, :consignee_email, :consignee_address,
                   :commodity_type, :weight_kg, :pieces, :volumetric_weight, :dimensions_json, :declared_value,
                   :total_amount, :currency, :payment_method, :booking_date)";

        $stmt = $this->conn->prepare($query);

        // Bind all params
        $params = [
            ':awb_number' => $data['awb_number'],
            ':flight_series_id' => $data['flight_series_id'],
            ':user_id' => $data['user_id'] ?? null,
            ':shipper_name' => $data['shipper_name'],
            ':shipper_company' => $data['shipper_company'] ?? null,
            ':shipper_phone' => $data['shipper_phone'],
            ':shipper_email' => $data['shipper_email'] ?? null,
            ':shipper_address' => $data['shipper_address'],
            ':consignee_name' => $data['consignee_name'],
            ':consignee_company' => $data['consignee_company'] ?? null,
            ':consignee_phone' => $data['consignee_phone'],
            ':consignee_email' => $data['consignee_email'] ?? null,
            ':consignee_address' => $data['consignee_address'],
            ':commodity_type' => $data['commodity_type'],
            ':weight_kg' => $data['weight_kg'],
            ':pieces' => $data['pieces'] ?? 1,
            ':volumetric_weight' => $data['volumetric_weight'] ?? null,
            ':dimensions_json' => $data['dimensions_json'] ?? null,
            ':declared_value' => $data['declared_value'] ?? 0,
            ':total_amount' => $data['total_amount'],
            ':currency' => $data['currency'] ?? 'KES',
            ':payment_method' => $data['payment_method'] ?? 'pending',
            ':booking_date' => $data['booking_date'] ?? date('Y-m-d')
        ];

        if ($stmt->execute($params)) {
            return [
                'status' => true,
                'id' => $this->conn->lastInsertID(),
                'awb' => $data['awb_number']
            ];
        }

        return ['status' => false, 'message' => 'Failed to record cargo booking'];
    }

    public function getByAWB($awb) {
        $query = "SELECT cb.*, 
                         fs.flt as flight_number, fs.std as departure_time, fs.sta as arrival_time,
                         d1.name as origin_city, d1.code as origin_code,
                         d2.name as destination_city, d2.code as destination_code
                  FROM " . $this->table_name . " cb
                  JOIN flight_series fs ON cb.flight_series_id = fs.id
                  JOIN destinations d1 ON fs.from_destination_id = d1.id
                  JOIN destinations d2 ON fs.to_destination_id = d2.id
                  WHERE cb.awb_number = :awb";

        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':awb', $awb);
        $stmt->execute();

        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    /**
     * Lightweight cargo capacity availability search.
     *
     * Returns rows shaped for the Svelte cargo-search UI:
     * - id (flight_series_id)
     * - airline
     * - flight_no
     * - origin / destination (IATA-ish codes)
     * - departure_date, departure_time, arrival_time
     * - duration
     * - available_capacity_kg
     * - max_pieces
     * - price_per_kg
     */
    public function searchAvailability(string $from, string $to, string $date, float $weight, string $commodity = 'general'): array
    {
        // Resolve destination IDs using the destinations table.
        $from = strtoupper(trim($from));
        $to = strtoupper(trim($to));

        $destStmt = $this->conn->prepare("SELECT id, code FROM destinations WHERE code IN (?, ?) LIMIT 2");
        $destStmt->execute([$from, $to]);
        $destRows = $destStmt->fetchAll(PDO::FETCH_ASSOC);

        $fromId = null;
        $toId = null;
        foreach ($destRows as $r) {
            if (($r['code'] ?? null) === $from) $fromId = (int)$r['id'];
            if (($r['code'] ?? null) === $to) $toId = (int)$r['id'];
        }

        if (!$fromId || !$toId) {
            return [];
        }

        // Price heuristics (until a real cargo pricing table exists).
        $pricePerKg = 120.0;
        try {
            $s = $this->conn->prepare("SELECT setting_value FROM settings WHERE setting_key = 'cargo_price_per_kg_default' LIMIT 1");
            $s->execute();
            $val = $s->fetch(PDO::FETCH_ASSOC);
            if (!empty($val['setting_value']) && is_numeric($val['setting_value'])) {
                $pricePerKg = (float)$val['setting_value'];
            }
        } catch (Exception $e) {
            // ignore: keep default
        }

        // Available capacity derived from aircraft max cargo weight minus booked cargo weights for the date.
        $query = "
            SELECT
                fs.id AS id,
                'Mc Aviation' AS airline,
                CONCAT(fs.flt, 'C') AS flight_no,
                d1.code AS origin,
                d2.code AS destination,
                ? AS departure_date,
                TIME_FORMAT(fs.std, '%H:%i') AS departure_time,
                TIME_FORMAT(fs.sta, '%H:%i') AS arrival_time,
                CONCAT(
                    LPAD(TIMESTAMPDIFF(HOUR, CONCAT(?, ' ', fs.std), CONCAT(?, ' ', fs.sta)), 1, '0'),
                    'h ',
                    LPAD(MOD(TIMESTAMPDIFF(MINUTE, CONCAT(?, ' ', fs.std), CONCAT(?, ' ', fs.sta)), 60), 2, '0'),
                    'm'
                ) AS duration,
                GREATEST(
                    0,
                    COALESCE(ac.max_cargo_weight, 0) - COALESCE(booked.total_weight, 0)
                ) AS available_capacity_kg,
                99 AS max_pieces,
                ? AS price_per_kg
            FROM flight_series fs
            JOIN destinations d1 ON fs.from_destination_id = d1.id
            JOIN destinations d2 ON fs.to_destination_id = d2.id
            LEFT JOIN aircrafts ac ON fs.aircraft_id = ac.id
            LEFT JOIN (
                SELECT flight_series_id, SUM(weight_kg) AS total_weight
                FROM cargo_bookings
                WHERE booking_date = ?
                  AND payment_status != 'cancelled'
                GROUP BY flight_series_id
            ) booked ON booked.flight_series_id = fs.id
            WHERE fs.from_destination_id = ?
              AND fs.to_destination_id = ?
              AND ? BETWEEN fs.start_date AND fs.end_date
            ORDER BY fs.std ASC
        ";

        $stmt = $this->conn->prepare($query);
        $stmt->execute([
            $date,
            $date, $date,
            $date, $date,
            $pricePerKg,
            $date,
            $fromId,
            $toId,
            $date
        ]);

        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

        // Filter by requested weight capacity in SQL result layer.
        $filtered = [];
        foreach ($rows as $r) {
            $cap = (float)($r['available_capacity_kg'] ?? 0);
            if ($cap >= $weight) {
                $filtered[] = $r;
            }
        }
        return $filtered;
    }
}
?>
