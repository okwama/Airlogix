<?php
class Response {
    public static function json($data, int $status = 200): void {
        // Clear any previous output
        if (ob_get_level() > 0) {
            ob_clean();
        }
        
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        
        $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json === false) {
            // Fallback if json_encode fails
            http_response_code(500);
            echo json_encode(['error' => 'Failed to encode response'], JSON_UNESCAPED_UNICODE);
        } else {
            echo $json;
        }
        exit;
    }
    public static function badRequest($msg) { self::json(['error'=>$msg], 400); }
    public static function unauthorized($msg='Unauthorized') { self::json(['error'=>$msg], 401); }
    public static function notFound($msg='Not found') { self::json(['error'=>$msg], 404); }
    public static function error($msg='Internal server error', int $status = 500) { self::json(['error'=>$msg], $status); }
    
    // Add conflict response for 409
    public static function conflict($msg='Conflict') { self::json(['error'=>$msg], 409); }
}


