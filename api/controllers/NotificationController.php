<?php

require_once __DIR__ . '/../models/Notification.php';
require_once __DIR__ . '/../utils/Response.php';

class NotificationController {
    private $db;
    private $notification;

    public function __construct($db) {
        $this->db = $db;
        $this->notification = new Notification($db);
    }

    // Get notifications for authenticated user
    public function getNotifications() {
        $user_id = $this->getAuthenticatedUserId();
        if (!$user_id) return;

        $limit = isset($_GET['limit']) ? $_GET['limit'] : 50;
        $notifications = $this->notification->getForUser($user_id, $limit);

        Response::json(['status' => true, 'message' => "Notifications retrieved", 'data' => $notifications]);
    }

    // Get unread count
    public function getUnreadCount() {
        $user_id = $this->getAuthenticatedUserId();
        if (!$user_id) return;

        $count = $this->notification->getUnreadCount($user_id);

        Response::json(['status' => true, 'message' => "Unread count retrieved", 'data' => ['unread_count' => (int)$count]]);
    }

    // Mark notification as read
    public function read($id) {
        $user_id = $this->getAuthenticatedUserId();
        if (!$user_id) return;

        if ($this->notification->markAsRead($id, $user_id)) {
            Response::json(['status' => true, 'message' => "Notification marked as read"]);
        } else {
            Response::fail(500, 'Failed to mark as read', 'NOTIFICATION_MARK_READ_FAILED');
        }
    }

    // Mark all as read
    public function readAll() {
        $user_id = $this->getAuthenticatedUserId();
        if (!$user_id) return;

        if ($this->notification->markAllAsRead($user_id)) {
            Response::json(['status' => true, 'message' => "All notifications marked as read"]);
        } else {
            Response::fail(500, 'Failed to mark all as read', 'NOTIFICATION_MARK_ALL_READ_FAILED');
        }
    }

    // Delete notification
    public function delete($id) {
        $user_id = $this->getAuthenticatedUserId();
        if (!$user_id) return;

        if ($this->notification->delete($id, $user_id)) {
            Response::json(['status' => true, 'message' => "Notification deleted"]);
        } else {
            Response::fail(500, 'Failed to delete notification', 'NOTIFICATION_DELETE_FAILED');
        }
    }

    private function getAuthenticatedUserId() {
        $headers = request_headers();
        $authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
        
        if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
            $token = $matches[1];
            require_once __DIR__ . '/../models/AirlineUser.php';
            $user_model = new AirlineUser($this->db);
            $user_id = $user_model->validateToken($token);
            
            if ($user_id) {
                return $user_id;
            }
        }
        
        Response::fail(401, 'Unauthorized', 'AUTH_UNAUTHORIZED');
        return null;
    }
}
