<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/Flight.php';
require_once __DIR__ . '/../utils/Response.php';

class FlightController {
    private $flightModel;

    public function __construct() {
        $db = db();
        $this->flightModel = new Flight($db);
    }

    public function search() {
        $from = $_GET['from'] ?? '';
        $to = $_GET['to'] ?? '';
        $date = $_GET['date'] ?? date('Y-m-d');

        if (empty($from) || empty($to)) {
            Response::fail(400, 'Origin and destination are required', 'FLIGHT_SEARCH_INPUT_INVALID');
            return;
        }

        // First, get destination IDs - this is fast and avoids expensive LIKE on joined tables
        require_once __DIR__ . '/../models/Destination.php';
        $db = db();
        $destModel = new Destination($db);
        
        // Search for matching destinations
        $fromDests = $destModel->search($from);
        $toDests = $destModel->search($to);
        
        if (empty($fromDests) || empty($toDests)) {
            Response::json(['status' => false, 'data' => [], 'message' => 'No matching destinations found']);
            return;
        }
        
        // Extract IDs
        $fromIds = array_column($fromDests, 'id');
        $toIds = array_column($toDests, 'id');
        
        // Search flights using destination IDs (much faster)
        $flights = $this->flightModel->searchByIds($fromIds, $toIds, $date);
        
        $suggestions = [];
        if (empty($flights)) {
            $suggestions = $this->flightModel->searchRelated($fromIds, $toIds, $date);
        }

        Response::json([
            'status' => true, 
            'data' => $flights,
            'suggestions' => $suggestions
        ]);
    }

    public function statusSearch() {
        $flight_number = $_GET['flight_number'] ?? null;
        $from = $_GET['from'] ?? null;
        $to = $_GET['to'] ?? null;
        $date = $_GET['date'] ?? date('Y-m-d');

        // If from/to are provided, we need to resolve them to IDs
        $from_id = null;
        $to_id = null;

        if ($from || $to) {
            require_once __DIR__ . '/../models/Destination.php';
            $db = db();
            $destModel = new Destination($db);

            if ($from) {
                $fromDests = $destModel->search($from);
                if (!empty($fromDests)) {
                    $from_id = $fromDests[0]['id'];
                }
            }

            if ($to) {
                $toDests = $destModel->search($to);
                if (!empty($toDests)) {
                    $to_id = $toDests[0]['id'];
                }
            }
        }

        $flights = $this->flightModel->searchStatus($flight_number, $from_id, $to_id, $date);
        Response::json(['status' => true, 'data' => $flights]);
    }

    public function get($id) {
        $flight = $this->flightModel->getById($id);
        if ($flight) {
            Response::json(['status' => true, 'data' => $flight]);
        } else {
            Response::fail(404, 'Flight not found', 'FLIGHT_NOT_FOUND');
        }
    }
}
?>
