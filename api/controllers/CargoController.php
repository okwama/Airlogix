<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/CargoBooking.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Cache.php';

class CargoController {
    private $cargoModel;

    public function __construct() {
        $db = db();
        $this->cargoModel = new CargoBooking($db);
    }

    private function generateAWB() {
        // Industry format: 450 + 8 digits, retry until unique.
        for ($i = 0; $i < 10; $i++) {
            $awb = "450-" . random_int(1000, 9999) . "-" . random_int(1000, 9999);
            if (!$this->cargoModel->awbExists($awb)) {
                return $awb;
            }
        }
        return null;
    }

    private function readRequestHeaders(): array
    {
        if (function_exists('request_headers')) {
            $headers = request_headers();
            if (is_array($headers)) {
                return $headers;
            }
        }

        if (function_exists('apache_request_headers')) {
            $headers = apache_request_headers();
            if (is_array($headers)) {
                return $headers;
            }
        }

        if (function_exists('getallheaders')) {
            $headers = getallheaders();
            if (is_array($headers)) {
                return $headers;
            }
        }

        $headers = [];
        foreach ($_SERVER as $key => $value) {
            if (strpos($key, 'HTTP_') !== 0) {
                continue;
            }
            $name = str_replace('_', ' ', strtolower(substr($key, 5)));
            $name = str_replace(' ', '-', ucwords($name));
            $headers[$name] = $value;
        }

        return $headers;
    }

    private function getCargoAccessTokenTtlSeconds(): int
    {
        $ttl = (int)env('CARGO_ACCESS_TOKEN_TTL_SECONDS', 86400);
        if ($ttl <= 0) {
            $ttl = 86400;
        }
        return $ttl;
    }

    private function issueCargoAccessToken(string $awb): string
    {
        $awb = strtoupper(trim($awb));
        if ($awb === '') {
            throw new RuntimeException('Cannot issue cargo access token for empty AWB');
        }

        $activeKey = "cargo_access_active:{$awb}";
        $previousTokenHash = Cache::get($activeKey);
        if (is_string($previousTokenHash) && $previousTokenHash !== '') {
            Cache::delete("cargo_access_session:{$previousTokenHash}");
        }

        $token = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $token);
        $ttl = $this->getCargoAccessTokenTtlSeconds();

        Cache::set("cargo_access_session:{$tokenHash}", ['awb' => $awb], $ttl);
        Cache::set($activeKey, $tokenHash, $ttl);

        return $token;
    }

    private function validateCargoAccessToken(string $awb, string $accessToken): bool
    {
        $awb = strtoupper(trim($awb));
        $accessToken = trim($accessToken);
        if ($awb === '' || $accessToken === '') {
            return false;
        }

        $tokenHash = hash('sha256', $accessToken);
        $activeTokenHash = Cache::get("cargo_access_active:{$awb}");
        if (!is_string($activeTokenHash) || $activeTokenHash === '' || !hash_equals($activeTokenHash, $tokenHash)) {
            return false;
        }

        $session = Cache::get("cargo_access_session:{$tokenHash}");
        if (!is_array($session)) {
            return false;
        }

        return strtoupper((string)($session['awb'] ?? '')) === $awb;
    }

    private function buildPublicTrackingData(array $booking): array
    {
        return [
            'awb_number' => (string)($booking['awb_number'] ?? ''),
            'status' => (string)($booking['status'] ?? ''),
            'booking_phase' => (string)($booking['booking_phase'] ?? ''),
            'payment_status' => (string)($booking['payment_status'] ?? ''),
            'flight_number' => (string)($booking['flight_number'] ?? ''),
            'departure_time' => (string)($booking['departure_time'] ?? ''),
            'arrival_time' => (string)($booking['arrival_time'] ?? ''),
            'origin_city' => (string)($booking['origin_city'] ?? ''),
            'origin_code' => (string)($booking['origin_code'] ?? ''),
            'destination_city' => (string)($booking['destination_city'] ?? ''),
            'destination_code' => (string)($booking['destination_code'] ?? ''),
            'commodity_type' => (string)($booking['commodity_type'] ?? ''),
            'weight_kg' => (float)($booking['weight_kg'] ?? 0),
            'pieces' => (int)($booking['pieces'] ?? 0),
            'booking_date' => (string)($booking['booking_date'] ?? '')
        ];
    }

    public function create() {
        $data = request_json();

        $requiredFields = [
            'flight_series_id',
            'shipper_name',
            'shipper_phone',
            'shipper_address',
            'consignee_name',
            'consignee_phone',
            'consignee_address',
            'weight_kg'
        ];
        foreach ($requiredFields as $field) {
            if (!isset($data[$field]) || $data[$field] === '') {
                Response::fail(400, "Field {$field} is required", 'CARGO_BOOKING_MISSING_FIELD', ['field' => $field]);
                return;
            }
        }

        $flightSeriesId = (int)$data['flight_series_id'];
        $weightKg = (float)$data['weight_kg'];
        $volumetricWeight = isset($data['volumetric_weight']) ? (float)$data['volumetric_weight'] : 0.0;
        $chargeableWeight = max($weightKg, $volumetricWeight > 0 ? $volumetricWeight : $weightKg);
        $commodity = strtolower(trim((string)($data['commodity_type'] ?? 'general')));
        $pieces = max(1, (int)($data['pieces'] ?? 1));
        $bookingDate = trim((string)($data['booking_date'] ?? date('Y-m-d')));

        if ($flightSeriesId <= 0) {
            Response::fail(400, 'Invalid flight series ID', 'CARGO_BOOKING_FLIGHT_INVALID');
            return;
        }
        if ($weightKg <= 0) {
            Response::fail(400, 'Invalid weight', 'CARGO_BOOKING_WEIGHT_INVALID');
            return;
        }
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $bookingDate)) {
            Response::fail(400, 'Invalid booking date format', 'CARGO_BOOKING_DATE_INVALID');
            return;
        }

        $quote = $this->cargoModel->quoteForFlightSeries($flightSeriesId, $bookingDate, $chargeableWeight, $commodity);
        if (!($quote['status'] ?? false)) {
            $code = (string)($quote['code'] ?? 'CARGO_QUOTE_FAILED');
            $message = (string)($quote['message'] ?? 'Could not quote cargo shipment');
            $statusCode = 400;
            if ($code === 'CARGO_FLIGHT_NOT_FOUND') {
                $statusCode = 404;
            } elseif ($code === 'CARGO_FLIGHT_DATE_OUT_OF_RANGE') {
                $statusCode = 409;
            }
            Response::fail($statusCode, $message, $code);
            return;
        }

        $availableCapacity = (float)($quote['available_capacity_kg'] ?? 0);
        if ($availableCapacity < $chargeableWeight) {
            Response::fail(
                409,
                'Insufficient cargo capacity for selected flight/date',
                'CARGO_CAPACITY_UNAVAILABLE',
                [
                    'requested_weight_kg' => $chargeableWeight,
                    'available_capacity_kg' => $availableCapacity
                ]
            );
            return;
        }

        $pricePerKg = (float)($quote['price_per_kg'] ?? 0);
        $serverTotal = round($chargeableWeight * $pricePerKg, 2);
        if (isset($data['total_amount']) && $data['total_amount'] !== '') {
            $clientTotal = (float)$data['total_amount'];
            if (abs($clientTotal - $serverTotal) > 0.01) {
                Response::fail(
                    400,
                    'Price mismatch. Cargo quote has changed or request payload was stale.',
                    'CARGO_PRICE_MISMATCH',
                    [
                        'expected_total' => $serverTotal,
                        'received_total' => $clientTotal
                    ]
                );
                return;
            }
        }

        $awb = $this->generateAWB();
        if ($awb === null) {
            Response::fail(500, 'Could not generate shipment reference', 'CARGO_AWB_GENERATION_FAILED');
            return;
        }

        $holdTtlMinutes = (int)env('CARGO_HOLD_TTL_MINUTES', 120);
        if ($holdTtlMinutes <= 0) {
            $holdTtlMinutes = 120;
        }

        $data['awb_number'] = $awb;
        $data['booking_date'] = $bookingDate;
        $data['commodity_type'] = $commodity !== '' ? $commodity : 'general';
        $data['pieces'] = $pieces;
        $data['weight_kg'] = $weightKg;
        $data['volumetric_weight'] = $volumetricWeight > 0 ? $volumetricWeight : null;
        $data['chargeable_weight_kg'] = $chargeableWeight;
        $data['capacity_snapshot_kg'] = $availableCapacity;
        $data['booking_phase'] = 'hold';
        $data['hold_expires_at'] = date('Y-m-d H:i:s', time() + ($holdTtlMinutes * 60));
        $data['total_amount'] = $serverTotal;
        $data['currency'] = strtoupper(trim((string)($data['currency'] ?? 'USD')));

        $result = $this->cargoModel->create($data);

        if ($result['status']) {
            Response::json([
                'status' => true,
                'message' => 'Cargo shipment booked successfully',
                'reference' => $result['awb'],
                'id' => $result['id'],
                'access_token' => $this->issueCargoAccessToken((string)$result['awb']),
                'data' => [
                    'total_amount' => $serverTotal,
                    'currency' => $data['currency'],
                    'price_per_kg' => $pricePerKg,
                    'chargeable_weight_kg' => $chargeableWeight,
                    'hold_expires_at' => $data['hold_expires_at']
                ]
            ]);
        } else {
            Response::fail(500, (string)($result['message'] ?? 'Failed to create cargo booking'), 'CARGO_BOOKING_CREATE_FAILED');
        }
    }

    public function get($reference) {
        $booking = $this->cargoModel->getByAWB($reference);

        if ($booking) {
            Response::json(['status' => true, 'data' => $this->buildPublicTrackingData($booking)]);
        } else {
            Response::fail(404, 'Cargo booking not found', 'CARGO_BOOKING_NOT_FOUND');
        }
    }

    public function getDetails($reference) {
        $booking = $this->cargoModel->getByAWB($reference);
        if (!$booking) {
            Response::fail(404, 'Cargo booking not found', 'CARGO_BOOKING_NOT_FOUND');
            return;
        }

        $headers = $this->readRequestHeaders();
        $accessToken = $headers['X-Cargo-Access-Token'] ?? '';
        if (!$this->validateCargoAccessToken((string)($booking['awb_number'] ?? $reference), (string)$accessToken)) {
            Response::fail(401, 'Unauthorized cargo access. Verify shipment access first.', 'CARGO_ACCESS_DENIED');
            return;
        }

        Response::json(['status' => true, 'data' => $booking]);
    }

    /**
     * Search cargo capacity availability (public).
     * Query params: from, to, date, weight, commodity
     */
    public function availability() {
        $from = $_GET['from'] ?? '';
        $to = $_GET['to'] ?? '';
        $date = $_GET['date'] ?? date('Y-m-d');
        $weight = isset($_GET['weight']) ? (float)$_GET['weight'] : 0.0;
        $commodity = $_GET['commodity'] ?? 'general';

        if (empty($from) || empty($to)) {
            Response::fail(400, 'Origin and destination are required', 'CARGO_AVAILABILITY_INPUT_INVALID');
            return;
        }

        if ($weight <= 0) {
            Response::fail(400, 'Valid weight is required', 'CARGO_AVAILABILITY_WEIGHT_INVALID');
            return;
        }

        $results = $this->cargoModel->searchAvailability($from, $to, $date, $weight, $commodity);
        Response::json(['status' => true, 'data' => $results]);
    }
}
?>
