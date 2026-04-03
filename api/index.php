<?php
// Enable error reporting in development (disable in production)
error_reporting(E_ALL);
ini_set('display_errors', 0); // Don't display errors to users
ini_set('log_errors', 1); // Log errors to error log

// CORS Headers Support
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// Handle Preflight OPTIONS Request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Set error handler to catch fatal errors.
// Travelers should only ever see a generic error, while full details go to logs.
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        error_log(sprintf(
            'Fatal error: %s in %s on line %d',
            $error['message'] ?? 'unknown',
            $error['file'] ?? 'unknown',
            $error['line'] ?? 0
        ));

        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'error' => 'Internal server error'
        ], JSON_UNESCAPED_UNICODE);
    }
});

require_once __DIR__.'/config.php';
require_once __DIR__.'/utils/Response.php';
require_once __DIR__.'/utils/Auth.php';
require_once __DIR__.'/controllers/AirlineUserController.php';
require_once __DIR__.'/controllers/FlightController.php';
require_once __DIR__.'/controllers/BookingController.php';
require_once __DIR__.'/controllers/PaymentController.php';
require_once __DIR__.'/controllers/CheckInController.php';
require_once __DIR__.'/controllers/HomeController.php';
require_once __DIR__.'/controllers/DestinationController.php';
require_once __DIR__.'/controllers/CurrencyController.php';
require_once __DIR__.'/controllers/LoyaltyController.php';
require_once __DIR__.'/controllers/NotificationController.php';
require_once __DIR__.'/controllers/CargoController.php';
require_once __DIR__.'/controllers/SettingsController.php';

// Get the request path
$requestUri = $_SERVER['REQUEST_URI'] ?? '/';
$path = parse_url($requestUri, PHP_URL_PATH);

$path = preg_replace('#^/api/airlogix#', '', $path);

// Remove version prefix (v1, v2, etc.) if present
if (preg_match('#^/v(\d+)#', $path, $matches)) {
    $path = substr($path, strlen($matches[0]));
}

$path = rtrim($path, '/');
if ($path === '') $path = '/';

// If path starts with /index.php, remove it
if (strpos($path, '/index.php') === 0) {
    $path = substr($path, 10);
    if ($path === '') $path = '/';
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($path === '' || $path === '/') { Response::json(['name'=>'Airlogix API','ok'=>true]); exit; }

if ($path === '/health' && $method==='GET') { Response::json(['status'=>'ok']); exit; }

// Initialize Database Connection
$db = db();

// Assert JWT is properly configured (fails fast if misconfigured).
Auth::assertJwtConfigured();

// Instantiate Controllers
$airlineUserCtrl = new AirlineUserController();
$flightCtrl = new FlightController();

// Auth Routes
if ($path === '/auth/register' && $method==='POST') { $airlineUserCtrl->register(); exit; }
if ($path === '/auth/login' && $method==='POST') { $airlineUserCtrl->login(); exit; }
if ($path === '/auth/profile' && ($method==='GET' || $method==='PUT')) { $airlineUserCtrl->profile(); exit; }
if ($path === '/auth/password' && $method==='PUT') { $airlineUserCtrl->changePassword(); exit; }
if (strpos($path, '/auth/device-token') === 0 && $method==='POST') { $airlineUserCtrl->registerDeviceToken(); exit; }
if (strpos($path, '/auth/forgot-password') === 0 && $method==='POST') { $airlineUserCtrl->forgotPassword(); exit; }
if (strpos($path, '/auth/reset-password') === 0 && $method==='POST') { $airlineUserCtrl->resetPassword(); exit; }
if (strpos($path, '/auth/delete-account') === 0 && $method==='DELETE') { $airlineUserCtrl->deleteAccount(); exit; }
if (strpos($path, '/auth/profile-photo') === 0 && $method==='POST') { $airlineUserCtrl->uploadProfilePhoto(); exit; }


// Flight Routes
if ($path === '/flights/search' && $method==='GET') { $flightCtrl->search(); exit; }
if ($path === '/flights/status' && $method==='GET') { $flightCtrl->statusSearch(); exit; }
if ($path === '/cabin-classes' && $method==='GET') {
    require_once __DIR__ . '/controllers/CabinClassController.php';
    $cabinClassCtrl = new CabinClassController($db);
    $cabinClassCtrl->list();
    exit;
}
if (preg_match('#^/flights/(\d+)$#', $path, $matches) && $method==='GET') { $flightCtrl->get($matches[1]); exit; }

// Booking Routes
$bookingCtrl = new BookingController();
if ($path === '/bookings' && $method==='POST') { $bookingCtrl->create(); exit; }
if ($path === '/bookings' && $method==='GET') {
    // Traveler-only: always require an authenticated traveler and only ever
    // return that traveler's bookings. No public listAll exposure.
    Auth::requireTravelerId($db);
    $bookingCtrl->listByUser();
    exit;
}
if (preg_match('#^/bookings/([A-Z0-9]+)/documents$#', $path, $matches) && $method==='GET') { $bookingCtrl->documents($matches[1]); exit; }
if (preg_match('#^/bookings/([A-Z0-9]+)$#', $path, $matches) && $method==='GET') { $bookingCtrl->get($matches[1]); exit; }
if ($path === '/bookings/find' && $method==='POST') { $bookingCtrl->find(); exit; }
if ($path === '/bookings/update_payment' && $method==='POST') { $bookingCtrl->updatePayment(); exit; }
if ($path === '/bookings/access/request' && $method==='POST') { $bookingCtrl->requestAccessCode(); exit; }
if ($path === '/bookings/access/verify' && $method==='POST') { $bookingCtrl->verifyAccessCode(); exit; }


// Payment Routes
$paymentCtrl = new PaymentController();
if ($path === '/payments/initiate' && $method==='POST') { $paymentCtrl->initiate(); exit; }
if ($path === '/payments/callback' && $method==='POST') { $paymentCtrl->callback(); exit; }

// Paystack Routes
if ($path === '/payments/paystack/initialize' && $method==='POST') { $paymentCtrl->initializePaystack(); exit; }
if ($path === '/payments/paystack/verify' && $method==='GET') { $paymentCtrl->verifyPaystack(); exit; }
if ($path === '/payments/paystack/webhook' && $method==='POST') { $paymentCtrl->paystackWebhook(); exit; }

// M-Pesa Routes
if ($path === '/payments/mpesa/initialize' && $method==='POST') { $paymentCtrl->initializeMpesa(); exit; }
if ($path === '/payments/mpesa/callback' && $method==='POST') { $paymentCtrl->mpesaCallback(); exit; }
if ($path === '/payments/mpesa/status' && $method==='GET') { $paymentCtrl->queryMpesaStatus(); exit; }

// Onafriq Routes (Mobile Money - Central Africa)
if ($path === '/payments/onafriq/initialize' && $method==='POST') { $paymentCtrl->initializeOnafriq(); exit; }
if ($path === '/payments/onafriq/callback' && $method==='POST') { $paymentCtrl->onafriqCallback(); exit; }
if ($path === '/payments/onafriq/status' && $method==='GET') { $paymentCtrl->onafriqStatus(); exit; }

// DPO Pay Routes (Cards - Central Africa)
if ($path === '/payments/dpo/initialize' && $method==='POST') { $paymentCtrl->initializeDPO(); exit; }
if ($path === '/payments/dpo/callback' && $method==='GET') { $paymentCtrl->dpoCallback(); exit; }
if ($path === '/payments/dpo/verify' && $method==='GET') { $paymentCtrl->verifyDPO(); exit; }

// Stripe Routes
if ($path === '/payments/stripe/initialize' && $method === 'POST') { $paymentCtrl->initializeStripe(); exit; }
if ($path === '/payments/stripe/webhook' && $method === 'POST') { $paymentCtrl->stripeWebhook(); exit; }


// Check-In Routes
$checkInCtrl = new CheckInController();
if ($path === '/checkin' && $method==='POST') { $checkInCtrl->create(); exit; }
if (preg_match('#^/checkin/(\d+)$#', $path, $matches) && $method==='GET') { $checkInCtrl->get($matches[1]); exit; }

// Cargo Routes
$cargoCtrl = new CargoController();
if ($path === '/cargo' && $method==='POST') { $cargoCtrl->create(); exit; }
if ($path === '/cargo/availability' && $method==='GET') { $cargoCtrl->availability(); exit; }
if (preg_match('#^/cargo/([A-Z0-9-]+)$#', $path, $matches) && $method==='GET') { $cargoCtrl->get($matches[1]); exit; }
// Allow alternative path for tracking
if (preg_match('#^/cargo/tracking/([A-Z0-9-]+)$#', $path, $matches) && $method==='GET') { $cargoCtrl->get($matches[1]); exit; }

// Destination Routes
$destinationCtrl = new DestinationController();
if ($path === '/destinations' && $method==='GET') { $destinationCtrl->list(); exit; }

// Cabin Class Routes
if ($path === '/cabin-classes' && $method==='GET') {
    require_once __DIR__ . '/controllers/CabinClassController.php';
    (new CabinClassController($db))->list();
    exit;
}

// Home Content Routes
$homeCtrl = new HomeController($db);
if ($path === '/home-content' && $method==='GET') { $homeCtrl->getContent(); exit; }

// Currency Routes
$currencyCtrl = new CurrencyController();
if ($path === '/currency/rates' && $method==='GET') { $currencyCtrl->getCachedRates(); exit; }
if ($path === '/currency/update') {
    // Internal-only endpoint: never called directly from traveler app.
    Auth::requireInternalKey();
    $currencyCtrl->updateRatesFromFixer();
    exit;
}

// Loyalty Routes
$loyaltyCtrl = new LoyaltyController();
if ($path === '/loyalty/info' && $method==='GET') { $loyaltyCtrl->getInfo(); exit; }
if ($path === '/loyalty/history' && $method==='GET') { $loyaltyCtrl->getHistory(); exit; }

// Notification Routes
$notificationCtrl = new NotificationController($db);
if ($path === '/notifications' && $method==='GET') { $notificationCtrl->getNotifications(); exit; }
if ($path === '/notifications/unread-count' && $method==='GET') { $notificationCtrl->getUnreadCount(); exit; }
if (preg_match('#^/notifications/read/(\d+)$#', $path, $matches) && $method==='POST') { $notificationCtrl->read($matches[1]); exit; }
if ($path === '/notifications/read-all' && $method==='POST') { $notificationCtrl->readAll(); exit; }
if (preg_match('#^/notifications/(\d+)$#', $path, $matches) && $method==='DELETE') { $notificationCtrl->delete($matches[1]); exit; }

// Settings & Config Routes
$settingsCtrl = new SettingsController();
if ($path === '/settings/bank-info' && $method === 'GET') { $settingsCtrl->getBankInfo(); exit; }

Response::notFound();
exit;
?>
