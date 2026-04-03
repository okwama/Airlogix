<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once __DIR__ . '/../utils/Cache.php';

class CurrencyController {
    private $db;
    private $apiKey; 
    private $baseUrl;

    public function __construct() {
        $this->db = db();
        $this->apiKey = env('FIXER_API_KEY');
        $this->baseUrl = env('FIXER_BASE_URL');
    }

    // Called by Cron Job or Admin
    public function updateRatesFromFixer() {
        $symbols = "USD,EUR,GBP,QAR,AED,SAR,KES,JPY,CNY";
        $url = $this->baseUrl . "?access_key=" . $this->apiKey . "&symbols=" . $symbols;

        $response = file_get_contents($url);
        if ($response === FALSE) {
            http_response_code(500);
            echo json_encode(["status" => false, "message" => "Failed to contact Fixer.io"]);
            return;
        }

        $data = json_decode($response, true);

        if (isset($data['success']) && $data['success']) {
            $rates = $data['rates'];
            
            // Insert or Update rates in DB
            $query = "INSERT INTO exchange_rates (currency_code, rate) VALUES (?, ?) 
                      ON DUPLICATE KEY UPDATE rate = VALUES(rate)";
            
            $stmt = $this->db->prepare($query);

            foreach ($rates as $code => $rate) {
                $stmt->execute([$code, $rate]);
            }

            echo json_encode(["status" => true, "message" => "Rates updated successfully", "timestamp" => date('Y-m-d H:i:s')]);
        } else {
            http_response_code(500);
            echo json_encode(["status" => false, "message" => "Fixer.io error: " . json_encode($data['error'])]);
        }
    }

    // Called by Apps (Android/iOS)
    public function getCachedRates() {
        // First, try API-level cache to avoid repeated DB hits across instances.
        $cacheKey = 'currency_rates';
        $cached = Cache::get($cacheKey);
        if ($cached !== null) {
            echo json_encode($cached);
            return;
        }

        // Fetch valid rates from DB
        $query = "SELECT currency_code, rate FROM exchange_rates";
        $stmt = $this->db->prepare($query);
        $stmt->execute();

        $rates = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $rates[$row['currency_code']] = (float)$row['rate'];
        }

        if (count($rates) > 0) {
            $payload = [
                "status" => true, 
                "base" => "EUR", // Fixer base
                "rates" => $rates
            ];

            $ttl = (int)env('CURRENCY_RATES_CACHE_TTL', 900); // 15 minutes default
            Cache::set($cacheKey, $payload, $ttl);

            echo json_encode($payload);
        } else {
            // Fallback if DB empty
            echo json_encode([
                "status" => false,
                "message" => "No rates found. Please run update."
            ]);
        }
    }

}