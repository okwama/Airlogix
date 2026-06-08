<?php
require_once __DIR__ . '/Notification.php';

class Loyalty {
    private $conn;

    public function __construct($db) {
        $this->conn = $db;
    }

    public function awardPoints($user_id, $booking_id, $amount, $description = "Points earned from booking") {
        // Points Calculation: 1 point per 100 units of currency
        $points = floor($amount / 100);
        if ($points <= 0) return true;

        try {
            $this->conn->beginTransaction();

            // 1. Log to loyalty_points_history
            $query = "INSERT INTO loyalty_points_history (user_id, booking_id, points, transaction_type, description) 
                      VALUES (:user_id, :booking_id, :points, 'EARN', :description)";
            $stmt = $this->conn->prepare($query);
            $stmt->execute([
                ':user_id' => $user_id,
                ':booking_id' => $booking_id,
                ':points' => $points,
                ':description' => $description
            ]);

            // Create notification
            $notification = new Notification($this->conn);
            $notification->create(
                $user_id,
                'loyalty',
                'Points Earned!',
                "You've just earned $points loyalty points for your booking. Keep flying to reach the next tier!"
            );

            // No separate OneSignal push: [PaymentControllerBase::notifyPaymentSuccess] already sends the
            // primary "Payment received" push in the same request; a second push would double-notify.

            // 2. Update airline_users total points
            $query = "UPDATE airline_users SET loyalty_points = loyalty_points + :points WHERE id = :id";
            $stmt = $this->conn->prepare($query);
            $stmt->execute([':points' => $points, ':id' => $user_id]);

            // 3. Recalculate Tier
            $this->updateUserTier($user_id);

            $this->conn->commit();
            return true;
        } catch (Exception $e) {
            $this->conn->rollBack();
            error_log("Loyalty awardPoints error: " . $e->getMessage());
            return false;
        }
    }

    public function getPointsHistory($user_id) {
        $query = "SELECT id, points, transaction_type, description, created_at 
                  FROM loyalty_points_history 
                  WHERE user_id = :user_id 
                  ORDER BY created_at DESC";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':user_id' => $user_id]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getTierInfo($user_id) {
        $query = "SELECT loyalty_points, member_club FROM airline_users WHERE id = :user_id";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':user_id' => $user_id]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user) return null;

        $points = $user['loyalty_points'];

        // Get all tiers to find current and next
        $query = "SELECT name, min_points FROM loyalty_tiers ORDER BY min_points ASC";
        $tiers = $this->conn->query($query)->fetchAll(PDO::FETCH_ASSOC);

        $currentTier = $user['member_club'];
        $nextTier = null;
        $pointsToNextTier = 0;

        foreach ($tiers as $index => $tier) {
            if ($points >= $tier['min_points']) {
                $currentTier = $tier['name'];
                if (isset($tiers[$index + 1])) {
                    $nextTier = $tiers[$index + 1]['name'];
                    $pointsToNextTier = $tiers[$index + 1]['min_points'] - $points;
                }
            }
        }

        return [
            'current_points' => $points,
            'current_tier' => $currentTier,
            'next_tier' => $nextTier,
            'points_to_next' => max(0, $pointsToNextTier)
        ];
    }

    private function updateUserTier($user_id) {
        $query = "SELECT loyalty_points FROM airline_users WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':id' => $user_id]);
        $points = $stmt->fetchColumn();

        // Find applicable tier
        $query = "SELECT name FROM loyalty_tiers WHERE min_points <= :points ORDER BY min_points DESC LIMIT 1";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':points' => $points]);
        $tierName = $stmt->fetchColumn();

        if ($tierName) {
            $query = "UPDATE airline_users SET member_club = :tier WHERE id = :id";
            $stmt = $this->conn->prepare($query);
            $stmt->execute([':tier' => $tierName, ':id' => $user_id]);
        }
    }
}
