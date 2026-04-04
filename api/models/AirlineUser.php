<?php
require_once __DIR__ . '/../utils/Jwt.php';

class AirlineUser {
    private $conn;
    private $table_name = "airline_users";

    public function __construct($db) {
        $this->conn = $db;
    }

    // Register new user
    public function register($data) {
        // Check if phone or email already exists
        $query = "SELECT id FROM " . $this->table_name . " WHERE phone_number = :phone OR email = :email";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':phone' => $data['phone_number'], ':email' => $data['email']]);
        
        if ($stmt->rowCount() > 0) {
            return ['status' => false, 'message' => 'Phone number or email already exists'];
        }

        // Insert new user
        $query = "INSERT INTO " . $this->table_name . " 
                 (phone_number, email, password_hash, first_name, last_name, nationality, passport_number) 
                 VALUES (:phone, :email, :password, :first_name, :last_name, :nationality, :passport_number)";
        
        $stmt = $this->conn->prepare($query);
        $password_hash = password_hash($data['password'], PASSWORD_BCRYPT);
        
        $params = [
            ':phone' => $data['phone_number'],
            ':email' => $data['email'],
            ':password' => $password_hash,
            ':first_name' => $data['first_name'],
            ':last_name' => $data['last_name'],
            ':nationality' => isset($data['nationality']) ? $data['nationality'] : null,
            ':passport_number' => isset($data['passport_number']) ? $data['passport_number'] : null
        ];

        if ($stmt->execute($params)) {
            return ['status' => true, 'message' => 'User registered successfully', 'user_id' => $this->conn->lastInsertId()];
        }

        return ['status' => false, 'message' => 'Registration failed'];
    }

        // Login user
    public function login($identifier, $password) {
        $query = "SELECT id, phone_number, email, password_hash, first_name, last_name, status, member_club, loyalty_points, 
                         date_of_birth, nationality, passport_number, passport_expiry_date, frequent_flyer_number, profile_photo_url, created_at, updated_at
                 FROM " . $this->table_name . " 
                 WHERE phone_number = :phone OR email = :email";
        
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':phone' => $identifier, ':email' => $identifier]);
        
        if ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            if (password_verify($password, $row['password_hash'])) {
                if ($row['status'] !== 'active') {
                    return ['status' => false, 'message' => 'Account is ' . $row['status']];
                }

                // Generate JWT (traveler-only role)
                $payload = [
                    'user_id' => $row['id'],
                    'phone' => $row['phone_number'],
                    'email' => $row['email'],
                    'role' => 'airline_user',
                    'exp' => time() + (60 * 60 * 24 * 30) // 30 days
                ];
                
                // Secret is validated early via Auth::assertJwtConfigured()
                $token = Jwt::sign($payload, env('JWT_SECRET', ''));

                unset($row['password_hash']); // Don't send hash back
                
                return [
                    'status' => true, 
                    'message' => 'Login successful', 
                    'token' => $token,
                    'user' => $row
                ];
            }
        }

        return ['status' => false, 'message' => 'Invalid credentials'];
    }

    // Validate Token (Helper)
    public function validateToken($token) {
        try {
            // Secret is validated early via Auth::assertJwtConfigured()
            $payload = Jwt::verify($token, env('JWT_SECRET', ''));
            if (!$payload || !isset($payload['user_id'])) {
                return false;
            }
            return $payload['user_id'];
        } catch (Exception $e) {
            return false;
        }
    }

    public function getProfile($user_id) {
        $query = "SELECT id, phone_number, email, first_name, last_name, date_of_birth, nationality, passport_number, frequent_flyer_number, profile_photo_url, created_at, member_club, loyalty_points 
                 FROM " . $this->table_name . " WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':id' => $user_id]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    public function updateProfile($user_id, $data) {
        $update_fields = [];
        $params = [];

        $allowed_fields = ['first_name', 'last_name', 'email', 'date_of_birth', 'nationality', 'passport_number', 'passport_expiry_date', 'frequent_flyer_number'];
        
        foreach ($allowed_fields as $field) {
            if (isset($data[$field])) {
                $update_fields[] = "$field = :$field";
                $params[":$field"] = $data[$field];
            }
        }

        if (empty($update_fields)) {
            return ['status' => false, 'message' => 'No fields to update'];
        }

        $query = "UPDATE " . $this->table_name . " SET " . implode(", ", $update_fields) . " WHERE id = :id";
        $params[':id'] = $user_id;

        $stmt = $this->conn->prepare($query);
        
        if ($stmt->execute($params)) {
            return ['status' => true, 'message' => 'Profile updated successfully'];
        } else {
            return ['status' => false, 'message' => 'Update failed'];
        }
    }

    public function changePassword($user_id, $current_password, $new_password) {
        // First verify current password
        $query = "SELECT password_hash FROM " . $this->table_name . " WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':id' => $user_id]);
        
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$row) {
            return ['status' => false, 'message' => 'User not found'];
        }
        
        if (!password_verify($current_password, $row['password_hash'])) {
            return ['status' => false, 'message' => 'Current password is incorrect'];
        }
        
        // Update to new password
        $new_hash = password_hash($new_password, PASSWORD_BCRYPT);
        $update_query = "UPDATE " . $this->table_name . " SET password_hash = :password WHERE id = :id";
        $update_stmt = $this->conn->prepare($update_query);
        
        if ($update_stmt->execute([':password' => $new_hash, ':id' => $user_id])) {
            return ['status' => true, 'message' => 'Password changed successfully'];
        } else {
            return ['status' => false, 'message' => 'Failed to update password'];
        }
    }

    public function saveDeviceToken($user_id, $token, $platform = 'ios') {
        // Upsert: Insert or Update if exists for this user and token
        $query = "INSERT INTO device_tokens (user_id, device_token, platform) 
                  VALUES (:user_id, :token, :platform)
                  ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP";
        
        $stmt = $this->conn->prepare($query);
        try {
            if ($stmt->execute([
                ':user_id' => $user_id,
                ':token' => $token,
                ':platform' => $platform
            ])) {
                return ['status' => true, 'message' => 'Device token saved successfully'];
            }
            return ['status' => false, 'message' => 'Failed to save device token'];
        } catch (PDOException $e) {
            error_log("Failed to save device token: " . $e->getMessage());
            return ['status' => false, 'message' => 'Database error'];
        }
    }
    // Save password reset code
    public function savePasswordResetCode($email, $code) {
        // Expiry time: 15 minutes from now
        $expires_at = date('Y-m-d H:i:s', strtotime('+15 minutes'));
        
        $query = "UPDATE " . $this->table_name . " 
                  SET password_reset_code = :code, password_reset_expires_at = :expires_at 
                  WHERE email = :email";
        
        $stmt = $this->conn->prepare($query);
        $params = [
            ':code' => $code,
            ':expires_at' => $expires_at,
            ':email' => $email
        ];
        
        if ($stmt->execute($params)) {
             // Check if any row was actually updated (meaning email exists)
            if ($stmt->rowCount() > 0) {
                return ['status' => true, 'message' => 'Reset code saved'];
            } else {
                return ['status' => false, 'message' => 'Email not found'];
            }
        }
        
        return ['status' => false, 'message' => 'Failed to save reset code'];
    }

    // Verify reset code
    public function verifyResetCode($email, $code) {
        $query = "SELECT id FROM " . $this->table_name . " 
                  WHERE email = :email 
                  AND password_reset_code = :code 
                  AND password_reset_expires_at > NOW()";
        
        $stmt = $this->conn->prepare($query);
        $stmt->execute([':email' => $email, ':code' => $code]);
        
        if ($stmt->rowCount() > 0) {
            return ['status' => true, 'message' => 'Code is valid'];
        }
        
        return ['status' => false, 'message' => 'Invalid or expired code'];
    }

    // Reset password with code
    public function resetPasswordWithCode($email, $code, $new_password) {
        // First verify code again to be safe
        $verify = $this->verifyResetCode($email, $code);
        if (!$verify['status']) {
            return $verify;
        }
        
        // Update password and clear reset code
        $new_hash = password_hash($new_password, PASSWORD_BCRYPT);
        
        $query = "UPDATE " . $this->table_name . " 
                  SET password_hash = :password, 
                      password_reset_code = NULL, 
                      password_reset_expires_at = NULL 
                  WHERE email = :email";
        
        $stmt = $this->conn->prepare($query);
        
        if ($stmt->execute([':password' => $new_hash, ':email' => $email])) {
            return ['status' => true, 'message' => 'Password reset successfully'];
        }
        
        return ['status' => false, 'message' => 'Failed to reset password'];
    }
    // Update profile photo
    public function updateProfilePhoto($user_id, $photo_url) {
        $query = "UPDATE " . $this->table_name . " SET profile_photo_url = :photo_url WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        
        if ($stmt->execute([':photo_url' => $photo_url, ':id' => $user_id])) {
            return ['status' => true, 'message' => 'Profile photo updated successfully', 'url' => $photo_url];
        } else {
            return ['status' => false, 'message' => 'Failed to update profile photo'];
        }
    }

    // Delete user account
    public function delete($id) {
        $query = "DELETE FROM " . $this->table_name . " WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        
        if ($stmt->execute([':id' => $id])) {
            return ['status' => true, 'message' => 'Account deleted successfully'];
        } else {
            return ['status' => false, 'message' => 'Failed to delete account'];
        }
    }
}
?>
