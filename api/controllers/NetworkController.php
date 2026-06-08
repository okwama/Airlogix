<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../utils/Response.php';

class NetworkController {
    public function getMapData() {
        $db = db();
        
        // Fetch all active destinations with coordinates
        // Column names from actual schema: code=iata, name=city, image=photo URL
        $query = "SELECT id, code as iata_code, name as city, longitude, latitude, image as image_url, destination as airport_name
                  FROM destinations 
                  WHERE status = 'active' AND latitude IS NOT NULL AND longitude IS NOT NULL";
                  
        try {
            $stmt = $db->query($query);
            $destinations = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // For now, we will return all destinations as connected to NBO.
            // In a more advanced setup, we would query the flight_series table to find active routes.
            $routes = [];
            foreach ($destinations as $dest) {
                if ($dest['iata_code'] !== 'NBO') {
                    $routes[] = [
                        'from' => 'NBO',
                        'to' => $dest['iata_code']
                    ];
                }
            }
            
            Response::json([
                'status' => true,
                'data' => [
                    'destinations' => $destinations,
                    'routes' => $routes,
                    'hub' => 'NBO'
                ]
            ]);
        } catch (PDOException $e) {
            Response::json(['status' => false, 'message' => 'Database error: ' . $e->getMessage()], 500);
        }
    }
}
?>
