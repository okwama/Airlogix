<?php

require_once __DIR__ . '/OneSignalService.php';

class NotificationDeliveryService
{
    private PDO $conn;
    private OneSignalService $oneSignal;

    public function __construct(PDO $conn)
    {
        $this->conn = $conn;
        $this->oneSignal = new OneSignalService();
    }

    public function isConfigured(): bool
    {
        return $this->oneSignal->isConfigured();
    }

    public function sendPushToUser(int $userId, string $title, string $message, array $data = [], ?string $url = null): array
    {
        if ($userId <= 0) {
            return ['status' => false, 'message' => 'Invalid user id'];
        }

        $subscriptionIds = $this->getActiveOneSignalSubscriptions($userId);
        if (empty($subscriptionIds)) {
            return ['status' => false, 'message' => 'No active OneSignal subscriptions found'];
        }

        return $this->oneSignal->sendPushToSubscriptions($subscriptionIds, $title, $message, $data, $url);
    }

    /**
     * @return string[]
     */
    private function getActiveOneSignalSubscriptions(int $userId): array
    {
        $query = "SELECT subscription_id
                  FROM push_subscriptions
                  WHERE user_id = :user_id
                    AND provider = 'onesignal'
                    AND status = 'active'";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':user_id' => $userId]);

        return array_values(array_filter($stmt->fetchAll(PDO::FETCH_COLUMN) ?: []));
    }
}
