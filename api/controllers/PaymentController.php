<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/Payment.php';
require_once __DIR__ . '/../models/Booking.php';
require_once __DIR__ . '/../models/BookingPassenger.php';
require_once __DIR__ . '/../models/AirlineUser.php';
require_once __DIR__ . '/../models/Loyalty.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Cache.php';

class PaymentController {
    private $paymentModel;
    private $bookingModel;
    private $userModel;

    public function __construct() {
        $db = db();
        $this->paymentModel = new Payment($db);
        $this->bookingModel = new Booking($db);
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

    private function canAccessBooking(array $booking): bool
    {
        $headers = request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';

        $authUserId = $this->userModel->validateToken($token);
        $isAuthorized = ($authUserId && (int)$authUserId === (int)($booking['user_id'] ?? 0));

        if (!$isAuthorized) {
            $accessToken = $headers['X-Booking-Access-Token'] ?? '';
            if (!empty($accessToken) && !empty($booking['booking_reference']) && !empty($booking['id'])) {
                $tokenHash = hash('sha256', trim((string)$accessToken));
                $activeTokenHash = Cache::get("booking_access_active:{$booking['booking_reference']}:{$booking['id']}");
                if (is_string($activeTokenHash) && $activeTokenHash !== '' && hash_equals($activeTokenHash, $tokenHash)) {
                    $session = Cache::get("booking_access_session:{$tokenHash}");
                    $isAuthorized = is_array($session)
                        && (int)($session['booking_id'] ?? 0) === (int)$booking['id']
                        && strtoupper((string)($session['reference'] ?? '')) === strtoupper((string)$booking['booking_reference']);
                }
            }
        }

        return $isAuthorized;
    }

    private function ensureActiveReservation(array $booking): void
    {
        if ($this->bookingModel->isReservationExpired($booking)) {
            $this->bookingModel->expireBooking((int)$booking['id']);
            Response::json([
                'status' => false,
                'message' => 'This reservation has expired. Please search again to create a new booking.'
            ], 409);
            exit();
        }
    }

    private function convertAmount($amount, $fromCurrency, $toCurrency) {
        if ($fromCurrency === $toCurrency) return $amount;
        
        $db = db();
        $stmt = $db->prepare("SELECT currency_code, rate FROM exchange_rates WHERE currency_code IN (?, ?)");
        $stmt->execute([$fromCurrency, $toCurrency]);
        $rates = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $rates[$row['currency_code']] = (float)$row['rate'];
        }
        
        if (!isset($rates[$fromCurrency]) || !isset($rates[$toCurrency])) {
            error_log("Conversion failed: missing rates for $fromCurrency or $toCurrency");
            return $amount; // Fallback to original
        }
        
        // Convert to base (EUR) then to target
        $amountInBase = $amount / $rates[$fromCurrency];
        return $amountInBase * $rates[$toCurrency];
    }

    private function callbackCacheKey(string $method, string $gatewayReference): string
    {
        return 'payment_callback_done:' . strtolower(trim($method)) . ':' . hash('sha256', trim($gatewayReference));
    }

    private function isCallbackAlreadyProcessed(string $method, ?string $gatewayReference): bool
    {
        $ref = trim((string)$gatewayReference);
        if ($ref === '') {
            return false;
        }
        return Cache::get($this->callbackCacheKey($method, $ref)) === true;
    }

    private function markCallbackProcessed(string $method, ?string $gatewayReference): void
    {
        $ref = trim((string)$gatewayReference);
        if ($ref === '') {
            return;
        }
        // Keep dedupe markers for 30 days to avoid replay effects from gateways.
        Cache::set($this->callbackCacheKey($method, $ref), true, 30 * 24 * 60 * 60);
    }

    /**
     * Idempotent helper to finalize a successful payment:
     * - Marks booking as paid (if not already)
     * - Persists gateway callback traceability
     * - Sends ticket
     * - Awards loyalty points
     */
    private function finalizeSuccessfulPayment(array $booking, string $method, ?string $gatewayReference = null, array $gatewayPayload = []): void
    {
        if (empty($booking['id'])) {
            return;
        }

        $gatewayReference = trim((string)$gatewayReference);
        $method = strtolower(trim($method));

        if ($gatewayReference !== '' && $this->isCallbackAlreadyProcessed($method, $gatewayReference)) {
            return;
        }

        $existingTrace = null;
        if ($gatewayReference !== '') {
            $existingTrace = $this->paymentModel->findByGatewayReference($gatewayReference);
            if (
                is_array($existingTrace)
                && (($existingTrace['status'] ?? '') === 'completed')
                && (($booking['payment_status'] ?? null) === 'paid')
            ) {
                $this->markCallbackProcessed($method, $gatewayReference);
                return;
            }
        }

        $traceMetadata = [
            'method' => $method,
            'gateway_reference' => $gatewayReference,
            'request_id' => Response::requestId(),
            'finalized_at' => date('Y-m-d H:i:s'),
            'payload' => $gatewayPayload
        ];

        // If booking is already paid, still persist a trace row so replayed callbacks are auditable.
        if (($booking['payment_status'] ?? null) === 'paid') {
            if (!is_array($existingTrace)) {
                $trace = $this->paymentModel->createGatewayTrace([
                    'booking_id' => $booking['id'],
                    'user_id' => $booking['user_id'] ?? null,
                    'amount' => $booking['total_amount'],
                    'currency' => $booking['currency'] ?? 'USD',
                    'payment_method' => $method,
                    'payment_reference' => $booking['booking_reference'],
                    'transaction_id' => $gatewayReference !== '' ? $gatewayReference : null,
                    'status' => 'completed',
                    'metadata' => json_encode(array_merge($traceMetadata, ['note' => 'Callback received after booking already paid'])),
                    'payment_date' => date('Y-m-d H:i:s')
                ]);
                if (!$trace['status']) {
                    error_log('Failed to record post-paid callback trace for booking ' . $booking['id']);
                }
            }
            $this->markCallbackProcessed($method, $gatewayReference);
            return;
        }

        $this->bookingModel->updatePaymentStatus(
            $booking['id'],
            'paid',
            $method
        );

        // Persist or update transaction record in the payment_transactions table
        if (is_array($existingTrace)) {
            $transactionResult = ['status' => true, 'transaction_id' => (int)$existingTrace['id']];
        } else {
            $transactionResult = $this->paymentModel->createGatewayTrace([
                'booking_id' => $booking['id'],
                'user_id' => $booking['user_id'] ?? null,
                'amount' => $booking['total_amount'],
                'currency' => $booking['currency'] ?? 'USD',
                'payment_method' => $method,
                'payment_reference' => $booking['booking_reference'],
                'transaction_id' => $gatewayReference !== '' ? $gatewayReference : null,
                'status' => 'pending',
                'metadata' => json_encode($traceMetadata)
            ]);
        }

        // Update the transaction status to completed, including callback metadata.
        if (!empty($transactionResult['transaction_id'])) {
            $this->paymentModel->updateStatus(
                $transactionResult['transaction_id'],
                'completed',
                $gatewayReference !== '' ? $gatewayReference : ($booking['booking_reference'] ?? null),
                json_encode($traceMetadata)
            );
        }

        // Issue Tickets (Generate ticket numbers)
        require_once __DIR__ . '/../services/TicketService.php';
        TicketService::getInstance()->issueTickets($booking['id']);

        // Send combined e-ticket & receipt
        TicketService::getInstance()->sendTicket(
            $this->bookingModel->getById($booking['id']),
            (new BookingPassenger(db()))->getByBookingId($booking['id'])
        );

        // Award Loyalty Points if user is logged in
        if (!empty($booking['user_id'])) {
            $loyalty = new Loyalty(db());
            $loyalty->awardPoints($booking['user_id'], $booking['id'], $booking['total_amount']);
        }

        $this->markCallbackProcessed($method, $gatewayReference);
    }

    public function updatePayment() {
        $data = request_json();
        
        if (empty($data['booking_id']) || empty($data['status'])) {
            Response::json(['status' => false, 'message' => 'Missing payment details'], 400);
            return;
        }

        $success = $this->bookingModel->updatePaymentStatus(
            $data['booking_id'],
            $data['status'],
            $data['payment_method'] ?? null
        );

        if ($success) {
            Response::json(['status' => true, 'message' => 'Payment status updated']);
        } else {
            Response::json(['status' => false, 'message' => 'Failed to update payment status'], 500);
        }
    }

    public function initializePaystack() {
        $data = request_json();

        // Validate required fields
        if (empty($data['email']) || empty($data['booking_reference'])) {
            Response::json(['status' => false, 'message' => 'Missing required payment details'], 400);
            return;
        }

        $booking = $this->bookingModel->getByReference($data['booking_reference']);
        if (!$booking) {
            Response::json(['status' => false, 'message' => 'Booking not found'], 404);
            return;
        }

        if (!$this->canAccessBooking($booking)) {
            Response::json(['status' => false, 'message' => 'Unauthorized booking access'], 401);
            return;
        }
        $this->ensureActiveReservation($booking);

        if (($booking['payment_status'] ?? null) === 'paid') {
            Response::conflict('Booking is already marked as paid');
        }

        $amount = (float)($booking['total_amount'] ?? 0);
        if ($amount <= 0) {
            Response::json(['status' => false, 'message' => 'Booking has invalid total amount'], 400);
            return;
        }

        require_once __DIR__ . '/../services/PaystackService.php';
        $paystack = new PaystackService();

        // Convert amount to minor units (Paystack expects the smallest currency unit)
        $currency = strtoupper((string)($data['currency'] ?? 'USD'));
        $amountInKobo = (int)round($this->convertAmount($amount, 'USD', $currency) * 100);

        $metadata = [
            'booking_reference' => $booking['booking_reference'],
            'custom_fields' => [
                [
                    'display_name' => 'Booking Reference',
                    'variable_name' => 'booking_reference',
                    'value' => $booking['booking_reference']
                ]
            ]
        ];

        $response = $paystack->initializeTransaction(
            $data['email'],
            $amountInKobo,
            $booking['booking_reference'],
            $metadata,
            $currency
        );

        if ($response['status']) {
            Response::json([
                'status' => true,
                'data' => $response['data'],
                'message' => 'Payment initialized successfully'
            ]);
        } else {
            Response::json([
                'status' => false,
                'message' => $response['message'] ?? 'Failed to initialize payment'
            ], 500);
        }
    }

    public function verifyPaystack() {
        $reference = $_GET['reference'] ?? '';

        if (empty($reference)) {
            Response::json(['status' => false, 'message' => 'Payment reference is required'], 400);
            return;
        }

        require_once __DIR__ . '/../services/PaystackService.php';
        $paystack = new PaystackService();

        $response = $paystack->verifyTransaction($reference);

        if ($response['status'] && isset($response['data'])) {
            $transactionData = $response['data'];

            // Update booking payment status
            if ($transactionData['status'] === 'success') {
                $bookingReference = $transactionData['metadata']['booking_reference'] ?? $reference;
                
                // Get booking by reference and finalize if found
                $booking = $this->bookingModel->getByReference($bookingReference);
                
                if ($booking) {
                    $gatewayRef = (string)($transactionData['reference'] ?? $reference);
                    $this->finalizeSuccessfulPayment($booking, 'paystack', $gatewayRef, $transactionData);

                    Response::json([
                        'status' => true,
                        'message' => 'Payment verified successfully',
                        'data' => $transactionData
                    ]);
                } else {
                    Response::json([
                        'status' => false,
                        'message' => 'Booking not found'
                    ], 404);
                }
            } else {
                Response::json([
                    'status' => false,
                    'message' => 'Payment not successful',
                    'data' => $transactionData
                ]);
            }
        } else {
            Response::json([
                'status' => false,
                'message' => $response['message'] ?? 'Failed to verify payment'
            ], 500);
        }
    }

    public function paystackWebhook() {
        // Verify webhook signature
        $input = file_get_contents('php://input');
        $signature = $_SERVER['HTTP_X_PAYSTACK_SIGNATURE'] ?? '';

        if (!$signature) {
            http_response_code(400);
            exit();
        }

        $webhookSecret = env('PAYSTACK_SECRET_KEY'); // Use secret key for signature verification
        if ($signature !== hash_hmac('sha512', $input, $webhookSecret)) {
             http_response_code(401);
             exit();
        }

        $event = json_decode($input, true);

        if ($event['event'] === 'charge.success') {
            $data = $event['data'];
            $reference = $data['reference'];
            $bookingReference = $data['metadata']['booking_reference'] ?? $reference;

            // Update booking status
            $booking = $this->bookingModel->getByReference($bookingReference);
            if ($booking) {
                $gatewayRef = (string)($data['reference'] ?? $reference);
                $this->finalizeSuccessfulPayment($booking, 'paystack', $gatewayRef, $data);
            }
        }

        http_response_code(200);
        echo json_encode(['status' => 'success']);
    }

    public function initializeMpesa() {
        $data = request_json();
        
        // Validate required fields
        if (empty($data['phone_number'])) {
            Response::json(['status' => false, 'message' => 'Phone number is required'], 400);
            return;
        }
        if (empty($data['booking_reference'])) {
            Response::json(['status' => false, 'message' => 'Booking reference is required'], 400);
            return;
        }
        
        // Ensure booking exists before initiating MPesa STK Push
        $booking = $this->bookingModel->getByReference($data['booking_reference']);
        if (!$booking) {
            Response::json(['status' => false, 'message' => 'Booking not found for reference: ' . ($data['booking_reference'] ?? '')], 404);
            return;
        }

        if (!$this->canAccessBooking($booking)) {
            Response::json(['status' => false, 'message' => 'Unauthorized booking access'], 401);
            return;
        }
        $this->ensureActiveReservation($booking);

        if (($booking['payment_status'] ?? null) === 'paid') {
            Response::conflict('Booking is already marked as paid');
        }

        $amount = (float)($booking['total_amount'] ?? 0);
        if ($amount <= 0) {
            Response::json(['status' => false, 'message' => 'Booking has invalid total amount'], 400);
            return;
        }

        require_once __DIR__ . '/../services/MpesaService.php';
        $mpesa = new MpesaService(db());

        $response = $mpesa->initiateStkPush(
            $data['phone_number'],
            $amount,
            $booking['booking_reference'],
            $data['description'] ?? 'Flight Booking Payment'
        );
        
        if ($response['status']) {
            // Update booking to indicate payment is pending
            if ($booking) {
                $this->bookingModel->updatePaymentStatus(
                    $booking['id'],
                    'pending',
                    'mpesa'
                );
            }
            
            Response::json([
                'status' => true,
                'message' => $response['message'],
                'data' => $response['data']
            ]);
        } else {
            Response::json([
                'status' => false, 
                'message' => $response['message'],
                'error_code' => $response['error_code'] ?? 'MPESA_ERROR'
            ], 500);
        }
    }

    public function mpesaCallback() {
        // Get raw POST data
        $rawInput = file_get_contents('php://input');
        $data = json_decode($rawInput, true);
        
        // Log raw callback for debugging
        $logDir = __DIR__ . '/../logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        file_put_contents(
            $logDir . '/mpesa_callbacks_' . date('Y-m-d') . '.log',
            date('Y-m-d H:i:s') . " CALLBACK: " . $rawInput . PHP_EOL,
            FILE_APPEND
        );
        
        if (!$data || !isset($data['Body']['stkCallback'])) {
            http_response_code(400);
            echo json_encode(['ResultCode' => 1, 'ResultDesc' => 'Invalid callback data']);
            exit();
        }
        
        require_once __DIR__ . '/../services/MpesaService.php';
        $mpesa = new MpesaService(db());
        
        $result = $mpesa->processCallback($data);
        
        if ($result['status'] && $result['payment_status'] === 'success') {
            // Payment successful - update booking
            $paymentData = $result['data'];
            $bookingReference = $paymentData['booking_reference'];
            
            if ($bookingReference) {
                $booking = $this->bookingModel->getByReference($bookingReference);
                
                if ($booking) {
                    $gatewayRef = (string)($paymentData['checkout_request_id'] ?? $paymentData['merchant_request_id'] ?? '');
                    $this->finalizeSuccessfulPayment($booking, 'mpesa', $gatewayRef, $paymentData);
                }
            }
            
            // Respond to Safaricom
            http_response_code(200);
            echo json_encode(['ResultCode' => 0, 'ResultDesc' => 'Callback processed successfully']);
        } else {
            // Payment failed or cancelled
            $paymentData = $result['data'] ?? [];
            $bookingReference = $paymentData['booking_reference'] ?? null;
            
            if ($bookingReference) {
                $booking = $this->bookingModel->getByReference($bookingReference);
                if ($booking) {
                    $this->bookingModel->updatePaymentStatus(
                        $booking['id'],
                        'failed',
                        'mpesa'
                    );
                }
            }
            
            http_response_code(200);
            echo json_encode(['ResultCode' => 0, 'ResultDesc' => 'Callback received']);
        }
        exit();
    }

    public function queryMpesaStatus() {
        $checkoutRequestId = $_GET['checkout_request_id'] ?? '';
        
        if (empty($checkoutRequestId)) {
            Response::json(['status' => false, 'message' => 'checkout_request_id is required'], 400);
            return;
        }
        
        require_once __DIR__ . '/../services/MpesaService.php';
        $mpesa = new MpesaService(db());
        
        $response = $mpesa->queryStkStatus($checkoutRequestId);
        
        Response::json($response);
    }

    public function initiate() {
        $user_id = $this->authenticate();
        $data = request_json();

        if (empty($data['booking_id']) || empty($data['amount']) || empty($data['payment_method'])) {
            Response::json(['status' => false, 'message' => 'Missing payment details: booking_id, amount, payment_method required'], 400);
            return;
        }

        // Verify booking exists and belongs to user
        $booking = $this->bookingModel->getById($data['booking_id']);
        
        if (!$booking) {
            Response::json(['status' => false, 'message' => 'Booking not found'], 404);
            return;
        }
        
        if ($booking['user_id'] != $user_id) {
            Response::json(['status' => false, 'message' => 'Unauthorized: Booking does not belong to you'], 403);
            return;
        }
        $this->ensureActiveReservation($booking);

        // Server-side integrity checks: ensure amount and status are valid before
        // handing off to any payment gateway.
        $requestedAmount = (float)$data['amount'];
        $expectedAmount = isset($booking['total_amount']) ? (float)$booking['total_amount'] : 0.0;
        $paymentStatus = $booking['payment_status'] ?? null;

        // Prevent re-payment of already paid bookings
        if ($paymentStatus === 'paid') {
            Response::conflict('Booking is already marked as paid');
        }

        if ($expectedAmount <= 0) {
            error_log('Booking ' . $booking['id'] . ' has non-positive total_amount; blocking payment initiate');
            Response::json(['status' => false, 'message' => 'Booking has invalid total amount'], 400);
        }

        // Allow for minor rounding differences, but block obvious tampering.
        // Convert expected amount (USD) to requested currency
        $requestedCurrency = $data['currency'] ?? 'USD';
        $normalizedExpected = $this->convertAmount($expectedAmount, 'USD', $requestedCurrency);

        $delta = abs($requestedAmount - $normalizedExpected);
        if ($delta > ($normalizedExpected * 0.05)) { // Allow 5% variance for rate fluctuations/rounding
            error_log("Payment total mismatch: Requested $requestedAmount $requestedCurrency, expected $normalizedExpected $requestedCurrency (Original: $expectedAmount USD)");
            Response::json([
                'status' => false,
                'message' => 'Amount does not match booking total',
                'details' => [
                    'requested' => $requestedAmount,
                    'expected' => round($normalizedExpected, 2),
                    'currency' => $requestedCurrency
                ]
            ], 400);
            return;
        }

        $paymentMethod = strtolower($data['payment_method']);
        
        // Route to appropriate payment gateway
        if ($paymentMethod === 'mpesa' || $paymentMethod === 'm-pesa') {
            // M-Pesa STK Push
            if (empty($data['phone_number'])) {
                Response::json(['status' => false, 'message' => 'Phone number required for M-Pesa'], 400);
                return;
            }
            
            require_once __DIR__ . '/../services/MpesaService.php';
            $mpesa = new MpesaService(db());
            
            $response = $mpesa->initiateStkPush(
                $data['phone_number'],
                $data['amount'],
                $booking['booking_reference'],
                'Flight Booking - ' . $booking['booking_reference']
            );
            
            if ($response['status']) {
                Response::json([
                    'status' => true,
                    'message' => $response['message'],
                    'payment_method' => 'mpesa',
                    'data' => $response['data']
                ]);
            } else {
                Response::json([
                    'status' => false,
                    'message' => $response['message'],
                    'error_code' => $response['error_code'] ?? 'MPESA_ERROR'
                ], 500);
            }
            
        } elseif ($paymentMethod === 'stripe') {
            // Stripe Card Payment
            if (empty($data['email'])) {
                Response::json(['status' => false, 'message' => 'Email required for Stripe payment'], 400);
                return;
            }
            
            require_once __DIR__ . '/../services/StripeService.php';
            $stripe = new StripeService();
            
            $response = $stripe->createCheckoutSession(
                $data['amount'],
                $data['currency'] ?? 'USD',
                $booking['booking_reference'],
                $data['email']
            );
            
            if ($response['status']) {
                Response::json([
                    'status' => true,
                    'message' => 'Stripe Session created',
                    'payment_method' => 'stripe',
                    'data' => $response['data']
                ]);
            } else {
                Response::json([
                    'status' => false,
                    'message' => $response['message'] ?? 'Failed to initialize Stripe payment'
                ], 500);
            }
            
        } else {
            Response::json(['status' => false, 'message' => 'Unsupported payment method: ' . $paymentMethod], 400);
        }
    }

    // Generic callback for payment confirmation (legacy support)
    public function callback() {
        $data = request_json();
        
        if (empty($data['transaction_id']) || empty($data['status'])) {
            Response::json(['status' => false, 'message' => 'Missing transaction_id or status'], 400);
            return;
        }
        
        $db = db();
        
        // Get the transaction from payment_transactions
        $stmt = $db->prepare("
            SELECT pt.*, b.booking_reference as booking_reference 
            FROM payment_transactions pt
            LEFT JOIN bookings b ON pt.booking_id = b.id
            WHERE pt.transaction_id = ? OR pt.payment_reference = ?
        ");
        $stmt->execute([$data['transaction_id'], $data['transaction_id']]);
        $transaction = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$transaction) {
            Response::json(['status' => false, 'message' => 'Transaction not found'], 404);
            return;
        }
        
        // Update payment transaction status
        $newStatus = ($data['status'] === 'completed' || $data['status'] === 'success') ? 'completed' : 'failed';
        
        $updateStmt = $db->prepare("
            UPDATE payment_transactions 
            SET status = ?, payment_date = NOW(), metadata = ?
            WHERE id = ?
        ");
        $updateStmt->execute([$newStatus, json_encode($data), $transaction['id']]);
        
        // Update booking status
        if ($newStatus === 'completed') {
            $this->bookingModel->updatePaymentStatus(
                $transaction['booking_id'],
                'paid',
                $transaction['payment_method']
            );
        } else {
            $this->bookingModel->updatePaymentStatus(
                $transaction['booking_id'],
                'failed',
                $transaction['payment_method']
            );
        }
        
        Response::json([
            'status' => true, 
            'message' => 'Payment status updated',
            'payment_status' => $newStatus
        ]);
    }

    // ==================== ONAFRIQ (Mobile Money) ====================

    public function initializeOnafriq() {
        $data = request_json();

        if (empty($data['phone_number']) || empty($data['booking_reference'])) {
            Response::json(['status' => false, 'message' => 'Missing required payment details'], 400);
            return;
        }

        $booking = $this->bookingModel->getByReference($data['booking_reference']);
        if (!$booking) {
            Response::json(['status' => false, 'message' => 'Booking not found'], 404);
            return;
        }

        if (!$this->canAccessBooking($booking)) {
            Response::json(['status' => false, 'message' => 'Unauthorized booking access'], 401);
            return;
        }
        $this->ensureActiveReservation($booking);

        if (($booking['payment_status'] ?? null) === 'paid') {
            Response::conflict('Booking is already marked as paid');
        }

        $amount = (float)($booking['total_amount'] ?? 0);
        if ($amount <= 0) {
            Response::json(['status' => false, 'message' => 'Booking has invalid total amount'], 400);
            return;
        }

        require_once __DIR__ . '/../services/OnafriqService.php';
        $db = db();
        $onafriq = new OnafriqService($db);

        $response = $onafriq->initiateMobileMoneyPayment(
            $data['phone_number'],
            $amount,
            $data['currency'] ?? 'USD',
            $booking['booking_reference'],
            $data['provider'] ?? 'orange',
            $data['country_code'] ?? '243'
        );

        if ($response['status']) {
            Response::json([
                'status' => true,
                'data' => $response['data'],
                'message' => $response['message']
            ]);
        } else {
            Response::json([
                'status' => false,
                'message' => $response['message'] ?? 'Failed to initialize payment'
            ], 500);
        }
    }

    public function onafriqCallback() {
        $callbackData = request_json();

        // Optional: Verify signature if Onafriq provides X-Signature header
        // $signature = $_SERVER['HTTP_X_ONAFRIQ_SIGNATURE'] ?? '';
        // verifySignature($callbackData, $signature);

        require_once __DIR__ . '/../services/OnafriqService.php';
        $db = db();
        $onafriq = new OnafriqService($db);

        $result = $onafriq->processCallback($callbackData);

        if ($result['status'] && $result['payment_status'] === 'success') {
            $bookingReference = $result['data']['booking_reference'];
            $booking = $this->bookingModel->getByReference($bookingReference);

            if ($booking) {
                $gatewayRef = (string)($result['data']['transaction_id'] ?? '');
                $this->finalizeSuccessfulPayment($booking, 'onafriq', $gatewayRef, $result['data']);
            }
        }
        
        // Respond to Onafriq to acknowledge receipt
        Response::json($result);
    }

    public function onafriqStatus() {
        $transactionId = $_GET['transaction_id'] ?? '';

        if (empty($transactionId)) {
            Response::json(['status' => false, 'message' => 'Transaction ID is required'], 400);
            return;
        }

        require_once __DIR__ . '/../services/OnafriqService.php';
        $db = db();
        $onafriq = new OnafriqService($db);

        $response = $onafriq->queryTransactionStatus($transactionId);
        Response::json($response);
    }

    // ==================== DPO PAY (Cards) ====================

    public function initializeDPO() {
        $data = request_json();

        if (empty($data['booking_reference']) || empty($data['email'])) {
            Response::json(['status' => false, 'message' => 'Missing required payment details'], 400);
            return;
        }

        $booking = $this->bookingModel->getByReference($data['booking_reference']);
        if (!$booking) {
            Response::json(['status' => false, 'message' => 'Booking not found'], 404);
            return;
        }

        if (!$this->canAccessBooking($booking)) {
            Response::json(['status' => false, 'message' => 'Unauthorized booking access'], 401);
            return;
        }
        $this->ensureActiveReservation($booking);

        if (($booking['payment_status'] ?? null) === 'paid') {
            Response::conflict('Booking is already marked as paid');
        }

        $amount = (float)($booking['total_amount'] ?? 0);
        if ($amount <= 0) {
            Response::json(['status' => false, 'message' => 'Booking has invalid total amount'], 400);
            return;
        }

        require_once __DIR__ . '/../services/DPOService.php';
        $db = db();
        $dpo = new DPOService($db);

        $response = $dpo->createToken(
            $amount,
            $data['currency'] ?? 'USD',
            $booking['booking_reference'],
            $data['email'],
            $data['customer_name'] ?? '',
            $data['phone_number'] ?? ''
        );

        if ($response['status']) {
            Response::json([
                'status' => true,
                'data' => $response['data'],
                'message' => $response['message']
            ]);
        } else {
            Response::json([
                'status' => false,
                'message' => $response['message'] ?? 'Failed to initialize payment'
            ], 500);
        }
    }

    public function dpoCallback() {
        // DPO sends data via GET parameters (TransToken, CompanyRef, etc.) or POST XML depending on config
        // Assuming GET redirection for browser return, and POST for server-to-server (if configured)
        
        $callbackData = $_GET; 
        
        // If empty GET, check input stream for XML (server-to-server notification)
        if (empty($callbackData)) {
            $input = file_get_contents('php://input');
            if (!empty($input)) {
                // Parse XML notification
                try {
                     $xml = simplexml_load_string($input);
                     $callbackData = json_decode(json_encode($xml), true);
                } catch (Exception $e) {
                    // Log error
                }
            }
        }

        require_once __DIR__ . '/../services/DPOService.php';
        $db = db();
        $dpo = new DPOService($db);

        $result = $dpo->processCallback($callbackData);

        if ($result['status'] && $result['payment_status'] === 'success') {
            $bookingReference = $result['data']['booking_reference'];
            $booking = $this->bookingModel->getByReference($bookingReference);

            if ($booking) {
                $gatewayRef = (string)($result['data']['trans_token'] ?? ($callbackData['TransToken'] ?? $callbackData['trans_token'] ?? ''));
                $this->finalizeSuccessfulPayment($booking, 'dpo', $gatewayRef, $result['data']);
            }
        }

        // If it's a browser redirect (has TransToken in GET), redirect users
        if (isset($_GET['TransToken']) || isset($_GET['trans_token'])) {
             $status = $result['payment_status'] === 'success' ? 'success' : 'failed';
             $ref = $result['data']['booking_reference'] ?? '';
             header("Location: " . env('APP_URL') . "/payment/result?status=$status&reference=$ref");
             exit();
        }
        
        // Otherwise acknowledge receipt (for server-to-server)
        echo "OK"; 
        exit();
    }

    public function verifyDPO() {
        $transToken = $_GET['trans_token'] ?? '';

        if (empty($transToken)) {
            Response::json(['status' => false, 'message' => 'Transaction token is required'], 400);
            return;
        }

        require_once __DIR__ . '/../services/DPOService.php';
        $db = db();
        $dpo = new DPOService($db);

        $response = $dpo->verifyTransaction($transToken);

        if ($response['status']) {
            Response::json([
                'status' => true,
                'data' => $response['data'],
                'transaction_status' => $response['transaction_status']
            ]);
        } else {
            Response::json([
                'status' => false,
                'message' => $response['message'] ?? 'Failed to verify payment'
            ], 500);
        }
    }

    // ==================== STRIPE ====================

    public function initializeStripe() {
        $data = request_json();
        
        if (empty($data['booking_reference']) || empty($data['email'])) {
            Response::json(['status' => false, 'message' => 'Missing required payment details'], 400);
            return;
        }

        $booking = $this->bookingModel->getByReference($data['booking_reference']);
        if (!$booking) {
            Response::json(['status' => false, 'message' => 'Booking not found'], 404);
            return;
        }

        if (!$this->canAccessBooking($booking)) {
            Response::json(['status' => false, 'message' => 'Unauthorized booking access'], 401);
            return;
        }
        $this->ensureActiveReservation($booking);

        if (($booking['payment_status'] ?? null) === 'paid') {
            Response::conflict('Booking is already marked as paid');
        }

        $currency = strtoupper((string)($data['currency'] ?? 'USD'));
        $amount = (float)($booking['total_amount'] ?? 0);
        if ($amount <= 0) {
            Response::json(['status' => false, 'message' => 'Booking has invalid total amount'], 400);
            return;
        }

        $convertedAmount = $currency === 'USD'
            ? $amount
            : $this->convertAmount($amount, 'USD', $currency);

        require_once __DIR__ . '/../services/StripeService.php';
        $stripe = new StripeService();

        $response = $stripe->createCheckoutSession(
            $convertedAmount,
            $currency,
            $booking['booking_reference'],
            $data['email']
        );

        Response::json($response);
    }

    public function stripeWebhook() {
        $rawInput = file_get_contents('php://input');
        $signature = $_SERVER['HTTP_STRIPE_SIGNATURE'] ?? '';
        $secret = env('STRIPE_WEBHOOK_SECRET', '');

        // Verify signature if configured (required for production safety).
        if (!empty($secret)) {
            if (empty($signature)) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'Missing Stripe-Signature header']);
                exit();
            }

            $signedPayloadOk = $this->verifyStripeSignature($rawInput, $signature, $secret);
            if (!$signedPayloadOk) {
                http_response_code(401);
                echo json_encode(['status' => 'error', 'message' => 'Invalid Stripe signature']);
                exit();
            }
        } else {
            // If secret is not set, still accept the webhook (dev), but log loudly.
            error_log('Stripe webhook received without STRIPE_WEBHOOK_SECRET configured');
        }

        $event = json_decode($rawInput, true);
        if (!$event) {
            http_response_code(400);
            exit();
        }

        if (($event['type'] ?? null) === 'checkout.session.completed') {
            $session = $event['data']['object'] ?? [];
            $bookingReference = $session['client_reference_id'] ?? ($session['metadata']['booking_reference'] ?? null);

            if ($bookingReference) {
                $booking = $this->bookingModel->getByReference($bookingReference);
                if ($booking) {
                    $this->finalizeSuccessfulPayment($booking, 'stripe', $session['id'] ?? null, $session);
                }
            }
        }

        http_response_code(200);
        echo json_encode(['status' => 'success']);
    }

    /**
     * Minimal Stripe signature verification compatible with webhook signing.
     * Avoids introducing external deps for this codebase.
     */
    private function verifyStripeSignature(string $payload, string $sigHeader, string $secret): bool
    {
        // Parse "t=...,v1=...,v0=..." format
        $parts = explode(',', $sigHeader);
        $timestamp = null;
        $signatures = [];

        foreach ($parts as $p) {
            $kv = explode('=', trim($p), 2);
            if (count($kv) !== 2) continue;
            [$k, $v] = $kv;
            if ($k === 't') $timestamp = $v;
            if ($k === 'v1') $signatures[] = $v;
        }

        if (empty($timestamp) || empty($signatures)) {
            return false;
        }

        // Optional tolerance window (default 5 minutes)
        $tolerance = (int)env('STRIPE_WEBHOOK_TOLERANCE_SECONDS', 300);
        if ($tolerance > 0) {
            $ts = (int)$timestamp;
            if (abs(time() - $ts) > $tolerance) {
                return false;
            }
        }

        $signedPayload = $timestamp . '.' . $payload;
        $expected = hash_hmac('sha256', $signedPayload, $secret);

        foreach ($signatures as $sig) {
            if (hash_equals($expected, $sig)) return true;
        }
        return false;
    }
}
?>
