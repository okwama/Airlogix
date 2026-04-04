<?php
require_once __DIR__ . '/../config.php';

class CargoBooking {
    private $conn;
    private $table_name = "cargo_bookings";
    private $columnCache = [];

    public function __construct($db) {
        $this->conn = $db;
    }

    public function create($data) {
        $columns = [
            'awb_number',
            'flight_series_id',
            'user_id',
            'shipper_name',
            'shipper_company',
            'shipper_phone',
            'shipper_email',
            'shipper_address',
            'consignee_name',
            'consignee_company',
            'consignee_phone',
            'consignee_email',
            'consignee_address',
            'commodity_type',
            'weight_kg',
            'pieces',
            'volumetric_weight',
            'dimensions_json',
            'declared_value',
            'total_amount',
            'currency',
            'payment_method',
            'booking_date'
        ];

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
            ':currency' => $data['currency'] ?? 'USD',
            ':payment_method' => $data['payment_method'] ?? 'pending',
            ':booking_date' => $data['booking_date'] ?? date('Y-m-d')
        ];

        if ($this->hasColumn($this->table_name, 'chargeable_weight_kg')) {
            $columns[] = 'chargeable_weight_kg';
            $params[':chargeable_weight_kg'] = $data['chargeable_weight_kg'] ?? $data['weight_kg'];
        }

        if ($this->hasColumn($this->table_name, 'booking_phase')) {
            $columns[] = 'booking_phase';
            $params[':booking_phase'] = $data['booking_phase'] ?? 'hold';
        }

        if ($this->hasColumn($this->table_name, 'hold_expires_at')) {
            $columns[] = 'hold_expires_at';
            $params[':hold_expires_at'] = $data['hold_expires_at'] ?? null;
        }

        if ($this->hasColumn($this->table_name, 'capacity_snapshot_kg')) {
            $columns[] = 'capacity_snapshot_kg';
            $params[':capacity_snapshot_kg'] = $data['capacity_snapshot_kg'] ?? null;
        }

        $placeholders = array_map(function ($c) {
            return ':' . $c;
        }, $columns);

        $query = "INSERT INTO " . $this->table_name . " (" . implode(', ', $columns) . ")
                  VALUES (" . implode(', ', $placeholders) . ")";

        $stmt = $this->conn->prepare($query);

        if ($stmt->execute($params)) {
            return [
                'status' => true,
                'id' => $this->conn->lastInsertID(),
                'awb' => $data['awb_number']
            ];
        }

        return ['status' => false, 'message' => 'Failed to record cargo booking'];
    }

    public function awbExists(string $awb): bool
    {
        $stmt = $this->conn->prepare("SELECT 1 FROM " . $this->table_name . " WHERE awb_number = ? LIMIT 1");
        $stmt->execute([$awb]);
        return (bool)$stmt->fetchColumn();
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

    public function getByUserId(int $userId): array
    {
        $query = "SELECT cb.*,
                         fs.flt as flight_number, fs.std as departure_time, fs.sta as arrival_time,
                         d1.name as origin_city, d1.code as origin_code,
                         d2.name as destination_city, d2.code as destination_code
                  FROM " . $this->table_name . " cb
                  JOIN flight_series fs ON cb.flight_series_id = fs.id
                  JOIN destinations d1 ON fs.from_destination_id = d1.id
                  JOIN destinations d2 ON fs.to_destination_id = d2.id
                  WHERE cb.user_id = :user_id
                  ORDER BY cb.booking_date DESC, cb.created_at DESC";

        $stmt = $this->conn->prepare($query);
        $stmt->bindValue(':user_id', $userId, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    }

    public function updatePaymentByAWB(string $awb, string $paymentStatus, ?string $paymentMethod = null): bool
    {
        $fields = ['payment_status = :payment_status'];
        $params = [
            ':payment_status' => $paymentStatus,
            ':awb' => strtoupper(trim($awb))
        ];

        if ($paymentMethod !== null && $paymentMethod !== '') {
            $fields[] = 'payment_method = :payment_method';
            $params[':payment_method'] = $paymentMethod;
        }

        $query = "UPDATE " . $this->table_name . " SET " . implode(', ', $fields) . " WHERE awb_number = :awb";
        $stmt = $this->conn->prepare($query);
        return $stmt->execute($params);
    }

    public function updateStatusByAWB(string $awb, string $status): bool
    {
        $query = "UPDATE " . $this->table_name . " SET status = :status WHERE awb_number = :awb";
        $stmt = $this->conn->prepare($query);
        return $stmt->execute([
            ':status' => $status,
            ':awb' => strtoupper(trim($awb))
        ]);
    }

    public function quoteForFlightSeries(
        int $flightSeriesId,
        string $date,
        float $weight,
        string $commodity = 'general'
    ): array {
        if ($flightSeriesId <= 0) {
            return ['status' => false, 'code' => 'CARGO_FLIGHT_INVALID', 'message' => 'Invalid flight selection'];
        }
        if ($weight <= 0) {
            return ['status' => false, 'code' => 'CARGO_WEIGHT_INVALID', 'message' => 'Invalid cargo weight'];
        }

        $bookingFilter = $this->activeBookedWeightFilterSql();
        $weightExpr = $this->bookedWeightExpressionSql();

        $query = "
            SELECT
                fs.id AS flight_series_id,
                fs.flt AS flight_no,
                fs.start_date,
                fs.end_date,
                d1.id AS from_id,
                d2.id AS to_id,
                d1.code AS from_code,
                d2.code AS to_code,
                GREATEST(
                    0,
                    COALESCE(cco.effective_capacity_kg, ac.max_cargo_weight, 0) - COALESCE(booked.total_weight, 0)
                ) AS available_capacity_kg
            FROM flight_series fs
            JOIN destinations d1 ON fs.from_destination_id = d1.id
            JOIN destinations d2 ON fs.to_destination_id = d2.id
            LEFT JOIN aircrafts ac ON fs.aircraft_id = ac.id
            LEFT JOIN cargo_capacity_overrides cco
                ON cco.flight_series_id = fs.id
               AND cco.override_date = ?
               AND cco.is_active = 1
            LEFT JOIN (
                SELECT flight_series_id, SUM({$weightExpr}) AS total_weight
                FROM cargo_bookings
                WHERE booking_date = ?
                  AND {$bookingFilter}
                GROUP BY flight_series_id
            ) booked ON booked.flight_series_id = fs.id
            WHERE fs.id = ?
            LIMIT 1
        ";

        $stmt = $this->conn->prepare($query);
        $stmt->execute([$date, $date, $flightSeriesId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) {
            return ['status' => false, 'code' => 'CARGO_FLIGHT_NOT_FOUND', 'message' => 'Flight not found'];
        }

        if ($date < (string)$row['start_date'] || $date > (string)$row['end_date']) {
            return ['status' => false, 'code' => 'CARGO_FLIGHT_DATE_OUT_OF_RANGE', 'message' => 'Flight is unavailable on selected date'];
        }

        $availableCapacity = (float)($row['available_capacity_kg'] ?? 0);
        $defaultPricePerKg = $this->resolveDefaultCargoPricePerKg();
        $pricePerKg = $this->resolveTariffPricePerKg(
            (int)$row['from_id'],
            (int)$row['to_id'],
            $date,
            $weight,
            $commodity,
            $defaultPricePerKg
        );

        return [
            'status' => true,
            'flight_series_id' => (int)$row['flight_series_id'],
            'flight_no' => (string)$row['flight_no'],
            'from_code' => (string)$row['from_code'],
            'to_code' => (string)$row['to_code'],
            'available_capacity_kg' => $availableCapacity,
            'price_per_kg' => $pricePerKg
        ];
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

        $defaultPricePerKg = $this->resolveDefaultCargoPricePerKg();
        $pricePerKg = $this->resolveTariffPricePerKg($fromId, $toId, $date, $weight, $commodity, $defaultPricePerKg);

        $bookingFilter = $this->activeBookedWeightFilterSql();
        $weightExpr = $this->bookedWeightExpressionSql();

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
                    COALESCE(cco.effective_capacity_kg, ac.max_cargo_weight, 0) - COALESCE(booked.total_weight, 0)
                ) AS available_capacity_kg,
                99 AS max_pieces,
                ? AS price_per_kg
            FROM flight_series fs
            JOIN destinations d1 ON fs.from_destination_id = d1.id
            JOIN destinations d2 ON fs.to_destination_id = d2.id
            LEFT JOIN aircrafts ac ON fs.aircraft_id = ac.id
            LEFT JOIN cargo_capacity_overrides cco
                ON cco.flight_series_id = fs.id
               AND cco.override_date = ?
               AND cco.is_active = 1
            LEFT JOIN (
                SELECT flight_series_id, SUM({$weightExpr}) AS total_weight
                FROM cargo_bookings
                WHERE booking_date = ?
                  AND {$bookingFilter}
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
            $date,
            $fromId,
            $toId,
            $date
        ]);

        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

        $filtered = [];
        foreach ($rows as $r) {
            $cap = (float)($r['available_capacity_kg'] ?? 0);
            if ($cap >= $weight) {
                $filtered[] = $r;
            }
        }
        return $filtered;
    }

    private function activeBookedWeightFilterSql(): string
    {
        if ($this->hasColumn($this->table_name, 'booking_phase')) {
            // No-hold mode: only confirmed bookings consume capacity.
            return "(booking_phase = 'confirmed')";
        }

        return "payment_status != 'cancelled'";
    }

    private function bookedWeightExpressionSql(): string
    {
        if ($this->hasColumn($this->table_name, 'chargeable_weight_kg')) {
            return "COALESCE(chargeable_weight_kg, weight_kg)";
        }
        return "weight_kg";
    }

    private function resolveDefaultCargoPricePerKg(): float
    {
        $pricePerKg = 120.0;
        try {
            $s = $this->conn->prepare("SELECT setting_value FROM settings WHERE setting_key = 'cargo_price_per_kg_default' LIMIT 1");
            $s->execute();
            $val = $s->fetch(PDO::FETCH_ASSOC);
            if (!empty($val['setting_value']) && is_numeric($val['setting_value'])) {
                $pricePerKg = (float)$val['setting_value'];
            }
        } catch (Exception $e) {
            // Keep fallback default.
        }
        return $pricePerKg;
    }

    private function resolveTariffPricePerKg(
        int $fromId,
        int $toId,
        string $date,
        float $weight,
        string $commodity,
        float $fallbackPrice
    ): float {
        $commodity = strtolower(trim($commodity));
        if ($commodity === '') {
            $commodity = 'general';
        }

        try {
            $q = "
                SELECT ct.price_per_kg
                FROM cargo_tariffs ct
                WHERE ct.is_active = 1
                  AND (ct.from_destination_id = ? OR ct.from_destination_id IS NULL)
                  AND (ct.to_destination_id = ? OR ct.to_destination_id IS NULL)
                  AND (LOWER(ct.commodity_type) = ? OR LOWER(ct.commodity_type) = 'general')
                  AND ct.min_weight_kg <= ?
                  AND (ct.max_weight_kg IS NULL OR ct.max_weight_kg >= ?)
                  AND (ct.effective_from IS NULL OR ct.effective_from <= ?)
                  AND (ct.effective_to IS NULL OR ct.effective_to >= ?)
                ORDER BY
                  CASE WHEN ct.from_destination_id = ? AND ct.to_destination_id = ? THEN 1 ELSE 0 END DESC,
                  CASE WHEN LOWER(ct.commodity_type) = ? THEN 1 ELSE 0 END DESC,
                  ct.min_weight_kg DESC,
                  ct.id DESC
                LIMIT 1
            ";
            $stmt = $this->conn->prepare($q);
            $stmt->execute([
                $fromId, $toId,
                $commodity,
                $weight, $weight,
                $date, $date,
                $fromId, $toId,
                $commodity
            ]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!empty($row['price_per_kg']) && is_numeric($row['price_per_kg'])) {
                return (float)$row['price_per_kg'];
            }
        } catch (Exception $e) {
            // Fallback to settings/default price if tariff table is not yet present.
        }

        return $fallbackPrice;
    }

    private function hasColumn(string $table, string $column): bool
    {
        $key = $table . '.' . $column;
        if (array_key_exists($key, $this->columnCache)) {
            return $this->columnCache[$key];
        }

        try {
            $stmt = $this->conn->prepare("SHOW COLUMNS FROM `{$table}` LIKE ?");
            $stmt->execute([$column]);
            $exists = (bool)$stmt->fetch(PDO::FETCH_ASSOC);
            $this->columnCache[$key] = $exists;
            return $exists;
        } catch (Exception $e) {
            $this->columnCache[$key] = false;
            return false;
        }
    }
}
?>
