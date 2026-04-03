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
            Response::fail(400, 'Incomplete data', 'AUTH_REGISTER_INCOMPLETE_DATA');
        }
    }

    public function login() {
        $data = request_json();
        if (!empty($data['identifier']) && !empty($data['password'])) {
            $response = $this->userModel->login($data['identifier'], $data['password']);
            echo json_encode($response);
        } else {
            Response::fail(400, 'Missing credentials', 'AUTH_LOGIN_MISSING_CREDENTIALS');
        }
    }

    public function profile() {
        $headers = request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::fail(401, 'Unauthorized', 'AUTH_UNAUTHORIZED');
            exit();
        }

        $request_method = $_SERVER["REQUEST_METHOD"];
        
        if ($request_method == 'GET') {
            $profile = $this->userModel->getProfile($user_id);
            if ($profile) {
                echo json_encode(['status' => true, 'data' => $profile]);
            } else {
                Response::fail(404, 'User not found', 'USER_NOT_FOUND');
            }
        }
        elseif ($request_method == 'PUT') {
            $data = request_json();
            $response = $this->userModel->updateProfile($user_id, $data);
            echo json_encode($response);
        }
    }

    public function changePassword() {
        $headers = request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::fail(401, 'Unauthorized', 'AUTH_UNAUTHORIZED');
            exit();
        }

        $data = request_json();
        
        if (empty($data['current_password']) || empty($data['new_password'])) {
            Response::fail(400, 'Current and new password are required', 'AUTH_PASSWORD_MISSING_FIELDS');
            return;
        }

        if (strlen($data['new_password']) < 8) {
            Response::fail(400, 'New password must be at least 8 characters', 'AUTH_PASSWORD_WEAK');
            return;
        }

        $response = $this->userModel->changePassword($user_id, $data['current_password'], $data['new_password']);
        echo json_encode($response);
    }

    public function registerDeviceToken() {
        $headers = request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::fail(401, 'Unauthorized', 'AUTH_UNAUTHORIZED');
            exit();
        }

        $data = request_json();
        if (empty($data['device_token'])) {
            Response::fail(400, 'Device token is required', 'DEVICE_TOKEN_REQUIRED');
            return;
        }

        $response = $this->userModel->saveDeviceToken($user_id, $data['device_token'], $data['platform'] ?? 'ios');
        echo json_encode($response);
    }
    public function forgotPassword() {
        $data = request_json();
        
        if (empty($data['email'])) {
            Response::fail(400, 'Email is required', 'AUTH_EMAIL_REQUIRED');
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
                Response::fail(500, 'Failed to send email. Please try again later.', 'PASSWORD_RESET_DELIVERY_FAILED');
            }
        } else {
            // If email doesn't exist, we should potentially return success anyway to prevent user enumeration.
            // But for this MVP, we'll return the actual error or a generic one.
            // Let's return a generic success message for security best practices, 
            // OR if it's an internal app, explicit error. 
            // The user requested MVP, so let's just say "If that email exists, we sent a code."
            // However, the mobile app expects a success/fail. 
            // Let's be explicit for now as per "MVP".
            Response::fail(404, 'Email address not found', 'PASSWORD_RESET_EMAIL_NOT_FOUND');
        }
    }

    public function resetPassword() {
        $data = request_json();
        
        if (empty($data['email']) || empty($data['code']) || empty($data['new_password'])) {
            Response::fail(400, 'Email, code, and new password are required', 'PASSWORD_RESET_MISSING_FIELDS');
            return;
        }
        
        if (strlen($data['new_password']) < 8) {
            Response::fail(400, 'Password must be at least 8 characters', 'AUTH_PASSWORD_WEAK');
            return;
        }
        
        $response = $this->userModel->resetPasswordWithCode($data['email'], $data['code'], $data['new_password']);
        
        if ($response['status']) {
            echo json_encode($response);
        } else {
            Response::fail(400, (string)($response['message'] ?? 'Failed to reset password'), 'PASSWORD_RESET_FAILED');
        }
    }
    public function uploadProfilePhoto() {
        $headers = request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::fail(401, 'Unauthorized', 'AUTH_UNAUTHORIZED');
            exit();
        }

        if (!isset($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
            error_log("Photo Upload Error: " . json_encode($_FILES));
            error_log("POST data: " . json_encode($_POST));
            Response::fail(400, 'No file uploaded or upload error', 'PROFILE_PHOTO_UPLOAD_MISSING');
            return;
        }

        $file = $_FILES['photo'];
        $allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'image/jpg'];
        
        if (!in_array($file['type'], $allowed_types)) {
            Response::fail(400, 'Invalid file type. Only JPG, PNG, and GIF allowed.', 'PROFILE_PHOTO_TYPE_INVALID');
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
                Response::fail(500, (string)($result['message'] ?? 'Failed to update profile photo'), 'PROFILE_PHOTO_UPDATE_FAILED');
            }
        } else {
            Response::fail(500, 'Failed to upload photo to Cloudinary', 'PROFILE_PHOTO_UPLOAD_FAILED');
        }
    }

    // Delete account
    public function deleteAccount() {
        $headers = request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::fail(401, 'Unauthorized', 'AUTH_UNAUTHORIZED');
            exit();
        }

        $result = $this->userModel->delete($user_id);
        
        if ($result['status']) {
            Response::json($result);
        } else {
            Response::fail(500, (string)($result['message'] ?? 'Failed to delete account'), 'ACCOUNT_DELETE_FAILED');
        }
    }
}
?>
