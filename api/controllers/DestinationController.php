<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/Destination.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Cache.php';

class DestinationController {
    private $destinationModel;

    public function __construct() {
        $db = db();
        $this->destinationModel = new Destination($db);
    }

    public function list() {
        $search = $_GET['search'] ?? '';
        
        if (!empty($search)) {
            $destinations = $this->destinationModel->search($search);
        } else {
            // Primary: always read latest data from DB.
            // If DB read fails, fall back to cached copy so UI keeps working when DB is unreachable.
            $cacheKey = 'destinations_all';
            try {
                $destinations = $this->destinationModel->getAll();
                // Update server-side cache with fresh copy (TTL configurable)
                $ttl = (int)env('DESTINATIONS_CACHE_TTL', 600);
                try {
                    Cache::set($cacheKey, $destinations, $ttl);
                } catch (Throwable $t) {
                    // Best-effort: don't fail the request if cache write fails
                    error_log('Failed to update destinations cache: ' . $t->getMessage());
                }
            } catch (Throwable $e) {
                // DB failure: use cached data if available
                $cached = Cache::get($cacheKey);
                if ($cached !== null) {
                    $destinations = $cached;
                } else {
                    // rethrow so caller sees failure with 500
                    throw $e;
                }
            }
        }
        
        Response::json(['status' => true, 'data' => $destinations]);
    }
}
?>
