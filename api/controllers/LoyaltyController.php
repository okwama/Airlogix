<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/Loyalty.php';
require_once __DIR__ . '/../models/AirlineUser.php';
require_once __DIR__ . '/../utils/Response.php';

class LoyaltyController {
    private $loyaltyModel;
    private $userModel;

    public function __construct() {
        $db = db();
        $this->loyaltyModel = new Loyalty($db);
        $this->userModel = new AirlineUser($db);
    }

    private function authenticate() {
        $headers = request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::json(['status' => false, 'message' => 'Unauthorized'], 401);
            exit();
        }
        return $user_id;
    }

    public function getInfo() {
        $user_id = $this->authenticate();
        $info = $this->loyaltyModel->getTierInfo($user_id);
        
        if ($info) {
            Response::json(['status' => true, 'data' => $info]);
        } else {
            Response::json(['status' => false, 'message' => 'Loyalty info not found'], 404);
        }
    }

    public function getHistory() {
        $user_id = $this->authenticate();
        $history = $this->loyaltyModel->getPointsHistory($user_id);
        Response::json(['status' => true, 'data' => $history]);
    }
}
