<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/CargoBooking.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Cache.php';

class CargoController {
    private $cargoModel;
    private $awbStockTableChecked = false;
    private $awbStockTableExists = false;

    public function __construct() {
        $db = db();
        $this->cargoModel = new CargoBooking($db);
    }

    private function generateAWB() {
        // IATA-like AWB format:
        // - 3-digit airline prefix (configurable)
        // - 7-digit serial + 1 check digit (mod 7)
        // - Rendered as PPP-XXXX-XXXX
        $prefix = $this->getAwbAirlinePrefix();

        if (!$this->hasAwbStockTable()) {
            throw new RuntimeException('AWB stock table is missing. Run the AWB stock migration first.');
        }

        $db = db();
        $maxAttempts = 100;

        try {
            $db->beginTransaction();

            $seedStmt = $db->prepare("
                INSERT INTO cargo_awb_stock (airline_prefix, next_serial)
                VALUES (?, 1)
                ON DUPLICATE KEY UPDATE airline_prefix = VALUES(airline_prefix)
            ");
            $seedStmt->execute([$prefix]);

            $lockStmt = $db->prepare("
                SELECT next_serial
                FROM cargo_awb_stock
                WHERE airline_prefix = ?
                FOR UPDATE
            ");
            $lockStmt->execute([$prefix]);
            $row = $lockStmt->fetch(PDO::FETCH_ASSOC);
            if (!$row) {
                throw new RuntimeException('Failed to load AWB stock row for prefix ' . $prefix);
            }

            $nextSerial = (int)($row['next_serial'] ?? 1);
            if ($nextSerial <= 0) {
                $nextSerial = 1;
            }

            $selectedAwb = null;

            for ($i = 0; $i < $maxAttempts; $i++) {
                if ($nextSerial > 9999999) {
                    throw new RuntimeException('AWB serial range exhausted for prefix ' . $prefix);
                }

                $awb = $this->formatAwbWithCheckDigit($prefix, $nextSerial);
                if (!$this->cargoModel->awbExists($awb)) {
                    $selectedAwb = $awb;
                    break;
                }

                $nextSerial++;
            }

            if ($selectedAwb === null) {
                throw new RuntimeException('Could not allocate a unique AWB from stock');
            }

            $advanceStmt = $db->prepare("
                UPDATE cargo_awb_stock
                SET next_serial = ?, updated_at = CURRENT_TIMESTAMP
                WHERE airline_prefix = ?
            ");
            $advanceStmt->execute([$nextSerial + 1, $prefix]);

            $db->commit();
            return $selectedAwb;
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            error_log('AWB generation failed: ' . $e->getMessage());
            return null;
        }
    }

    private function hasAwbStockTable(): bool
    {
        if ($this->awbStockTableChecked) {
            return $this->awbStockTableExists;
        }

        $this->awbStockTableChecked = true;
        try {
            $stmt = db()->query("SHOW TABLES LIKE 'cargo_awb_stock'");
            $this->awbStockTableExists = (bool)$stmt->fetch(PDO::FETCH_NUM);
        } catch (Throwable $e) {
            $this->awbStockTableExists = false;
        }

        return $this->awbStockTableExists;
    }

    private function getAwbAirlinePrefix(): string
    {
        $prefix = preg_replace('/\D+/', '', (string)env('CARGO_AWB_AIRLINE_PREFIX', '450'));
        if (!is_string($prefix) || strlen($prefix) === 0) {
            $prefix = '450';
        }
        if (strlen($prefix) > 3) {
            $prefix = substr($prefix, -3);
        }
        return str_pad($prefix, 3, '0', STR_PAD_LEFT);
    }

    private function formatAwbWithCheckDigit(string $prefix, int $serial7): string
    {
        $sevenDigitSerial = str_pad((string)$serial7, 7, '0', STR_PAD_LEFT);
        $checkDigit = ((int)$sevenDigitSerial) % 7;
        $serial8 = $sevenDigitSerial . (string)$checkDigit;
        return $prefix . '-' . substr($serial8, 0, 4) . '-' . substr($serial8, 4, 4);
    }

    private function normalizeAwb(string $rawAwb): ?string
    {
        $digits = preg_replace('/\D+/', '', strtoupper(trim($rawAwb)));
        if (!is_string($digits) || strlen($digits) !== 11) {
            return null;
        }

        $prefix = substr($digits, 0, 3);
        $serial8 = substr($digits, 3, 8);
        $serial7 = substr($serial8, 0, 7);
        $checkDigit = (int)substr($serial8, 7, 1);

        if (((int)$serial7 % 7) !== $checkDigit) {
            return null;
        }

        return $prefix . '-' . substr($serial8, 0, 4) . '-' . substr($serial8, 4, 4);
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
        $normalizedAwb = $this->normalizeAwb($awb);
        if ($normalizedAwb === null) {
            throw new RuntimeException('Cannot issue cargo access token for empty AWB');
        }

        $activeKey = "cargo_access_active:{$normalizedAwb}";
        $previousTokenHash = Cache::get($activeKey);
        if (is_string($previousTokenHash) && $previousTokenHash !== '') {
            Cache::delete("cargo_access_session:{$previousTokenHash}");
        }

        $token = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $token);
        $ttl = $this->getCargoAccessTokenTtlSeconds();

        Cache::set("cargo_access_session:{$tokenHash}", ['awb' => $normalizedAwb], $ttl);
        Cache::set($activeKey, $tokenHash, $ttl);

        return $token;
    }

    private function validateCargoAccessToken(string $awb, string $accessToken): bool
    {
        $awb = $this->normalizeAwb($awb) ?? '';
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

        $data['awb_number'] = $awb;
        $data['booking_date'] = $bookingDate;
        $data['commodity_type'] = $commodity !== '' ? $commodity : 'general';
        $data['pieces'] = $pieces;
        $data['weight_kg'] = $weightKg;
        $data['volumetric_weight'] = $volumetricWeight > 0 ? $volumetricWeight : null;
        $data['chargeable_weight_kg'] = $chargeableWeight;
        $data['capacity_snapshot_kg'] = $availableCapacity;
        // No-hold mode: treat newly created cargo bookings as confirmed immediately.
        $data['booking_phase'] = 'confirmed';
        $data['hold_expires_at'] = null;
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
                    'chargeable_weight_kg' => $chargeableWeight
                ]
            ]);
        } else {
            Response::fail(500, (string)($result['message'] ?? 'Failed to create cargo booking'), 'CARGO_BOOKING_CREATE_FAILED');
        }
    }

    public function get($reference) {
        $awb = $this->normalizeAwb((string)$reference);
        if ($awb === null) {
            Response::fail(400, 'Invalid AWB format', 'CARGO_AWB_INVALID');
            return;
        }

        $booking = $this->cargoModel->getByAWB($awb);

        if ($booking) {
            Response::json(['status' => true, 'data' => $this->buildPublicTrackingData($booking)]);
        } else {
            Response::fail(404, 'Cargo booking not found', 'CARGO_BOOKING_NOT_FOUND');
        }
    }

    public function getDetails($reference) {
        $awb = $this->normalizeAwb((string)$reference);
        if ($awb === null) {
            Response::fail(400, 'Invalid AWB format', 'CARGO_AWB_INVALID');
            return;
        }

        $booking = $this->cargoModel->getByAWB($awb);
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
     * Public: request a one-time access code for cargo AWB + email.
     */
    public function requestAccessCode() {
        $data = request_json();
        $awb = $this->normalizeAwb((string)($data['awb'] ?? $data['reference'] ?? ''));
        $email = strtolower(trim((string)($data['email'] ?? '')));

        if ($awb === null || $email === '') {
            Response::fail(400, 'Missing AWB or email', 'CARGO_ACCESS_INPUT_INVALID');
            return;
        }

        $ip = client_ip();
        $rateKey = "cargo_access_rl:" . $ip . ":" . $awb;
        $rate = Cache::get($rateKey);
        $count = is_array($rate) ? (int)($rate['count'] ?? 0) : 0;
        if ($count >= 5) {
            Response::fail(429, 'Too many requests. Try again later.', 'CARGO_ACCESS_RATE_LIMITED');
            return;
        }
        Cache::set($rateKey, ['count' => $count + 1], 600);

        $cooldownSeconds = (int)env('CARGO_ACCESS_RESEND_COOLDOWN_SECONDS', 60);
        if ($cooldownSeconds <= 0) {
            $cooldownSeconds = 60;
        }
        $cooldownKey = "cargo_access_cd:" . $awb . ":" . $email;
        if (Cache::get($cooldownKey)) {
            Response::json(['status' => true, 'message' => 'If the shipment exists, a code has been sent.']);
            return;
        }

        $booking = $this->cargoModel->getByAWB($awb);
        if (!$booking) {
            Response::json(['status' => true, 'message' => 'If the shipment exists, a code has been sent.']);
            return;
        }

        $shipperEmail = strtolower(trim((string)($booking['shipper_email'] ?? '')));
        $consigneeEmail = strtolower(trim((string)($booking['consignee_email'] ?? '')));
        $emailMatch = ($shipperEmail !== '' && $shipperEmail === $email) || ($consigneeEmail !== '' && $consigneeEmail === $email);
        if (!$emailMatch) {
            Response::json(['status' => true, 'message' => 'If the shipment exists, a code has been sent.']);
            return;
        }

        $code = (string)random_int(100000, 999999);
        $otpKey = "cargo_access_otp:" . $awb . ":" . $email;
        Cache::set($otpKey, ['code_hash' => hash('sha256', $code), 'attempts' => 0], 600);
        Cache::set($cooldownKey, ['sent' => 1], $cooldownSeconds);

        require_once __DIR__ . '/../services/EmailService.php';
        $recipientName = (string)(
            ($shipperEmail === $email ? ($booking['shipper_name'] ?? '') : ($booking['consignee_name'] ?? ''))
            ?: 'Customer'
        );
        $sentEmail = EmailService::getInstance()->sendCargoAccessCode($email, $recipientName, $awb, $code);

        $sentSms = false;
        $phone = trim((string)(
            $shipperEmail === $email
                ? ($booking['shipper_phone'] ?? '')
                : ($booking['consignee_phone'] ?? '')
        ));
        if ($phone !== '') {
            require_once __DIR__ . '/../services/SmsService.php';
            $sms = SmsService::getInstance();
            if ($sms->isConfigured()) {
                $msg = "Mc Aviation cargo access code for {$awb}: {$code}. Expires in 10 minutes.";
                $sentSms = $sms->send($phone, $msg);
            }
        }

        if (!$sentEmail && !$sentSms) {
            Response::fail(500, 'Failed to send access code. Try again later.', 'CARGO_ACCESS_DELIVERY_FAILED');
            return;
        }

        Response::json(['status' => true, 'message' => 'Access code sent.']);
    }

    /**
     * Public: verify one-time cargo access code and issue access token.
     */
    public function verifyAccessCode() {
        $data = request_json();
        $awb = $this->normalizeAwb((string)($data['awb'] ?? $data['reference'] ?? ''));
        $email = strtolower(trim((string)($data['email'] ?? '')));
        $code = trim((string)($data['code'] ?? ''));

        if ($awb === null || $email === '' || $code === '') {
            Response::fail(400, 'Missing AWB, email, or code', 'CARGO_ACCESS_INPUT_INVALID');
            return;
        }

        $ip = client_ip();
        $verifyRateKey = "cargo_access_verify_rl:" . $ip . ":" . $awb . ":" . $email;
        $verifyRate = Cache::get($verifyRateKey);
        $verifyCount = is_array($verifyRate) ? (int)($verifyRate['count'] ?? 0) : 0;
        if ($verifyCount >= 10) {
            Response::fail(429, 'Too many verification attempts. Try again later.', 'CARGO_ACCESS_VERIFY_RATE_LIMITED');
            return;
        }

        $otpKey = "cargo_access_otp:" . $awb . ":" . $email;
        $stored = Cache::get($otpKey);
        $storedHash = '';
        $attempts = 0;
        if (is_array($stored)) {
            $storedHash = (string)($stored['code_hash'] ?? '');
            $attempts = (int)($stored['attempts'] ?? 0);
            if ($storedHash === '' && !empty($stored['code'])) {
                $storedHash = hash('sha256', (string)$stored['code']);
            }
        }

        if ($storedHash === '' || !hash_equals($storedHash, hash('sha256', $code))) {
            $attempts++;
            Cache::set($verifyRateKey, ['count' => $verifyCount + 1], 600);
            if (is_array($stored)) {
                if ($attempts >= 5) {
                    Cache::delete($otpKey);
                } else {
                    Cache::set($otpKey, ['code_hash' => $storedHash, 'attempts' => $attempts], 600);
                }
            }
            if ($attempts >= 5) {
                Response::fail(403, 'Too many invalid attempts. Request a new code.', 'CARGO_ACCESS_CODE_LOCKED');
                return;
            }
            Response::fail(403, 'Invalid or expired code', 'CARGO_ACCESS_CODE_INVALID');
            return;
        }

        Cache::delete($otpKey);

        $booking = $this->cargoModel->getByAWB($awb);
        if (!$booking) {
            Response::fail(404, 'Cargo booking not found', 'CARGO_BOOKING_NOT_FOUND');
            return;
        }

        $accessToken = $this->issueCargoAccessToken((string)$booking['awb_number']);
        Response::json([
            'status' => true,
            'message' => 'Verified',
            'access_token' => $accessToken
        ]);
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
