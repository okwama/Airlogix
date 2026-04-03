<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/AirlineUser.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../services/CloudinaryService.php';

class AirlineUserController {
    private $userModel;

    public function __construct() {
        $db = db();
        $this->userModel = new AirlineUser($db);
    }

    public function register() {
        $data = request_json();
        if (!empty($data['phone_number']) && !empty($data['password']) && !empty($data['first_name']) && !empty($data['last_name'])) {
            $response = $this->userModel->register($data);
            echo json_encode($response);
        } else {
            Response::json(['status' => false, 'message' => 'Incomplete data'], 400);
        }
    }

    public function login() {
        $data = request_json();
        if (!empty($data['identifier']) && !empty($data['password'])) {
            $response = $this->userModel->login($data['identifier'], $data['password']);
            echo json_encode($response);
        } else {
            Response::json(['status' => false, 'message' => 'Missing credentials'], 400);
        }
    }

    public function profile() {
        $headers = apache_request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::json(['status' => false, 'message' => 'Unauthorized'], 401);
            exit();
        }

        $request_method = $_SERVER["REQUEST_METHOD"];
        
        if ($request_method == 'GET') {
            $profile = $this->userModel->getProfile($user_id);
            if ($profile) {
                echo json_encode(['status' => true, 'data' => $profile]);
            } else {
                echo json_encode(['status' => false, 'message' => 'User not found']);
            }
        }
        elseif ($request_method == 'PUT') {
            $data = request_json();
            $response = $this->userModel->updateProfile($user_id, $data);
            echo json_encode($response);
        }
    }

    public function changePassword() {
        $headers = apache_request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::json(['status' => false, 'message' => 'Unauthorized'], 401);
            exit();
        }

        $data = request_json();
        
        if (empty($data['current_password']) || empty($data['new_password'])) {
            Response::json(['status' => false, 'message' => 'Current and new password are required'], 400);
            return;
        }

        if (strlen($data['new_password']) < 8) {
            Response::json(['status' => false, 'message' => 'New password must be at least 8 characters'], 400);
            return;
        }

        $response = $this->userModel->changePassword($user_id, $data['current_password'], $data['new_password']);
        echo json_encode($response);
    }

    public function registerDeviceToken() {
        $headers = apache_request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::json(['status' => false, 'message' => 'Unauthorized'], 401);
            exit();
        }

        $data = request_json();
        if (empty($data['device_token'])) {
            Response::json(['status' => false, 'message' => 'Device token is required'], 400);
            return;
        }

        $response = $this->userModel->saveDeviceToken($user_id, $data['device_token'], $data['platform'] ?? 'ios');
        echo json_encode($response);
    }
    public function forgotPassword() {
        $data = request_json();
        
        if (empty($data['email'])) {
            Response::json(['status' => false, 'message' => 'Email is required'], 400);
            return;
        }
        
        $email = $data['email'];
        
        // Generate 6-digit code
        $code = str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
        
        // Save code to DB
        $result = $this->userModel->savePasswordResetCode($email, $code);
        
        if ($result['status']) {
            // Send email
            require_once __DIR__ . '/../services/EmailService.php';
            $emailService = EmailService::getInstance();
            
            // For security, we don't expose if the email failed to send, 
            // but in dev we might want to log it.
            // We assume the user exists because savePasswordResetCode returned true.
            // We need the user's name for the email.
            // A small optimization would be to fetch the user first, but let's keep it simple.
            // Since we don't have the name readily available without another query, 
            // we'll just use "Valued Customer" or fetch it.
            
            // Let's fetch the name briefly to make the email personal
            // This is a bit inefficient but good for UX.
            // Alternatively, we can just specificy "User" in the email service if name is missing.
            
            // Actually, let's just send the email. The service handles the structure.
            $emailSent = $emailService->sendPasswordReset($email, "User", $code);
            
            if ($emailSent) {
                Response::json(['status' => true, 'message' => 'Password reset code sent to your email']);
            } else {
                Response::json(['status' => false, 'message' => 'Failed to send email. Please try again later.'], 500);
            }
        } else {
            // If email doesn't exist, we should potentially return success anyway to prevent user enumeration.
            // But for this MVP, we'll return the actual error or a generic one.
            // Let's return a generic success message for security best practices, 
            // OR if it's an internal app, explicit error. 
            // The user requested MVP, so let's just say "If that email exists, we sent a code."
            // However, the mobile app expects a success/fail. 
            // Let's be explicit for now as per "MVP".
            Response::json(['status' => false, 'message' => 'Email address not found'], 404);
        }
    }

    public function resetPassword() {
        $data = request_json();
        
        if (empty($data['email']) || empty($data['code']) || empty($data['new_password'])) {
            Response::json(['status' => false, 'message' => 'Email, code, and new password are required'], 400);
            return;
        }
        
        if (strlen($data['new_password']) < 8) {
            Response::json(['status' => false, 'message' => 'Password must be at least 8 characters'], 400);
            return;
        }
        
        $response = $this->userModel->resetPasswordWithCode($data['email'], $data['code'], $data['new_password']);
        
        if ($response['status']) {
            echo json_encode($response);
        } else {
            Response::json($response, 400);
        }
    }
    public function uploadProfilePhoto() {
        $headers = apache_request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::json(['status' => false, 'message' => 'Unauthorized'], 401);
            exit();
        }

        if (!isset($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
            error_log("Photo Upload Error: " . json_encode($_FILES));
            error_log("POST data: " . json_encode($_POST));
            Response::json(['status' => false, 'message' => 'No file uploaded or upload error'], 400);
            return;
        }

        $file = $_FILES['photo'];
        $allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'image/jpg'];
        
        if (!in_array($file['type'], $allowed_types)) {
            Response::json(['status' => false, 'message' => 'Invalid file type. Only JPG, PNG, and GIF allowed.'], 400);
            return;
        }

        // Upload to Cloudinary
        $cloudinary = CloudinaryService::getInstance();
        $uploadResult = $cloudinary->uploadFile($file['tmp_name'], 'profile_photos');
        
        if ($uploadResult) {
            $file_url = $uploadResult['secure_url'];
            
            $result = $this->userModel->updateProfilePhoto($user_id, $file_url);
            
            if ($result['status']) {
                // Fetch updated user to return to the app
                $updatedUser = $this->userModel->getProfile($user_id);
                Response::json([
                    'status' => true,
                    'message' => 'Profile photo updated successfully',
                    'data' => $updatedUser
                ]);
            } else {
                Response::json($result, 500);
            }
        } else {
            Response::json(['status' => false, 'message' => 'Failed to upload photo to Cloudinary'], 500);
        }
    }

    // Delete account
    public function deleteAccount() {
        $headers = apache_request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::json(['status' => false, 'message' => 'Unauthorized'], 401);
            exit();
        }

        $result = $this->userModel->delete($user_id);
        
        if ($result['status']) {
            Response::json($result);
        } else {
            Response::json($result, 500);
        }
    }
}
?>
