<?php
require_once __DIR__ . '/../models/CabinClass.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Cache.php';

class CabinClassController {
    private $db;
    private $cabinClassModel;

    public function __construct($db) {
        $this->db = $db;
        $this->cabinClassModel = new CabinClass($db);
    }

    public function list() {
        try {
            $cacheKey = 'cabin_classes_all';
            $cached = Cache::get($cacheKey);
            if ($cached !== null) {
                $classes = $cached;
            } else {
                $classes = $this->cabinClassModel->getAll();
                $ttl = (int)env('CABIN_CLASSES_CACHE_TTL', 600); // 10 minutes default
                Cache::set($cacheKey, $classes, $ttl);
            }
            Response::json(['status' => true, 'data' => $classes]);
        } catch (Exception $e) {
            Response::error($e->getMessage(), 500);
        }
    }
}
?>
