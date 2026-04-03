<?php

require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Cache.php';

class HomeController {
    private $db;

    public function __construct($db) {
        $this->db = $db;
    }

    public function getContent() {
        try {
            $cacheKey = 'home_content';
            $cached = Cache::get($cacheKey);
            if ($cached !== null) {
                Response::json([
                    'status' => true,
                    'message' => "Home content retrieved (cached)",
                    'data' => $cached
                ]);
            }

            // 1. Fetch Popular Destinations
            // Mapping: name column -> city, destination column -> name (airport name)
            $destinationsQuery = "SELECT 
                                    d.id, 
                                    COALESCE(d.destination, d.name) as name, 
                                    d.code, 
                                    d.image_url as image_url, 
                                    c.name as country, 
                                    d.name as city,
                                    COALESCE(d.is_popular, 0) as is_popular
                                FROM destinations d 
                                LEFT JOIN Country c ON d.country_id = c.id 
                                WHERE d.status = 'active' 
                                LIMIT 6";
            $destinations = $this->db->query($destinationsQuery)->fetchAll(PDO::FETCH_ASSOC);

            // 2. Fetch Active Offers
            $offersQuery = "SELECT id, title, description, image_url, promo_code FROM offers WHERE is_active = 1";
            $offers = $this->db->query($offersQuery)->fetchAll(PDO::FETCH_ASSOC);

            // 3. Fetch Partner Hotels (with new fields)
            $hotelsQuery = "SELECT id, name, location, image_url, price_per_night, rating, description, amenities, review_count, booking_url FROM hotels WHERE is_active = 1";
            $hotels = $this->db->query($hotelsQuery)->fetchAll(PDO::FETCH_ASSOC);
            // convert amenities JSON string to array for each hotel
            foreach ($hotels as &$h) {
                if (isset($h['amenities']) && $h['amenities'] !== null) {
                    $decoded = json_decode($h['amenities'], true);
                    $h['amenities'] = is_array($decoded) ? $decoded : [];
                } else {
                    $h['amenities'] = [];
                }
            }

            // 4. Fetch Experiences
            $experiencesQuery = "SELECT id, title, subtitle, icon, color_hex FROM experiences WHERE is_active = 1";
            $experiences = $this->db->query($experiencesQuery)->fetchAll(PDO::FETCH_ASSOC);

            $payload = [
                'destinations' => $destinations,
                'offers' => $offers,
                'hotels' => $hotels,
                'experiences' => $experiences
            ];

            $ttl = (int)env('HOME_CONTENT_CACHE_TTL', 300); // 5 minutes default
            Cache::set($cacheKey, $payload, $ttl);

            Response::json([
                'status' => true,
                'message' => "Home content retrieved",
                'data' => $payload
            ]);
        } catch (Exception $e) {
            Response::json(['status' => false, 'message' => "Failed to retrieve home content: " . $e->getMessage()], 500);
        }
    }
}
