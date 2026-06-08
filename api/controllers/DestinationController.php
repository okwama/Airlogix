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
            // Cache full destinations list for a short period to reduce DB load.
            $cacheKey = 'destinations_all';
            $cached = Cache::get($cacheKey);
            if ($cached !== null) {
                $destinations = $cached;
            } else {
                $destinations = $this->destinationModel->getAll();
                // Default TTL: 10 minutes (600s)
                $ttl = (int)env('DESTINATIONS_CACHE_TTL', 600);
                Cache::set($cacheKey, $destinations, $ttl);
            }
        }
        
        Response::json(['status' => true, 'data' => $destinations]);
    }
}
?>
