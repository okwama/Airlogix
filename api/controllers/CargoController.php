<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/CargoBooking.php';
require_once __DIR__ . '/../utils/Response.php';

class CargoController {
    private $cargoModel;

    public function __construct() {
        $db = db();
        $this->cargoModel = new CargoBooking($db);
    }

    private function generateAWB() {
        // Industry Standard format: 450 (Mc Aviation) + 8 digits
        return "450-" . rand(1000, 9999) . "-" . rand(1000, 9999);
    }

    public function create() {
        $data = request_json();

        // Validation
        $requiredFields = ['flight_series_id', 'shipper_name', 'consignee_name', 'weight_kg', 'total_amount'];
        foreach ($requiredFields as $field) {
            if (empty($data[$field])) {
                Response::fail(400, "Field $field is required", 'CARGO_BOOKING_MISSING_FIELD', ['field' => $field]);
                return;
            }
        }

        // Generate custom AWB
        $data['awb_number'] = $this->generateAWB();
        $data['booking_date'] = date('Y-m-d');

        $result = $this->cargoModel->create($data);

        if ($result['status']) {
            Response::json([
                'status' => true,
                'message' => 'Cargo shipment booked successfully',
                'reference' => $result['awb'],
                'id' => $result['id']
            ]);
        } else {
            Response::fail(500, (string)($result['message'] ?? 'Failed to create cargo booking'), 'CARGO_BOOKING_CREATE_FAILED');
        }
    }

    public function get($reference) {
        $booking = $this->cargoModel->getByAWB($reference);

        if ($booking) {
            Response::json(['status' => true, 'data' => $booking]);
        } else {
            Response::fail(404, 'Cargo booking not found', 'CARGO_BOOKING_NOT_FOUND');
        }
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
