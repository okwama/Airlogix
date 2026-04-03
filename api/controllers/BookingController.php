<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/Booking.php';
require_once __DIR__ . '/../models/Passenger.php';
require_once __DIR__ . '/../models/BookingPassenger.php';
require_once __DIR__ . '/../models/AirlineUser.php'; // For token validation
require_once __DIR__ . '/../models/Loyalty.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Cache.php';

class BookingController {
    private $bookingModel;
    private $passengerModel;
    private $bookingPassengerModel;
    private $userModel;

    public function __construct() {
        $db = db();
        $this->bookingModel = new Booking($db);
        $this->passengerModel = new Passenger($db);
        $this->bookingPassengerModel = new BookingPassenger($db);
        $this->userModel = new AirlineUser($db);
    }

    private function authenticate() {
        $headers = $this->readRequestHeaders();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::fail(401, 'Unauthorized', 'AUTH_UNAUTHORIZED');
            exit();
        }
        return $user_id;
    }

    private function getGuestAccessTokenTtlSeconds(array $booking): int
    {
        $defaultTtl = (int)env('BOOKING_ACCESS_TOKEN_TTL_SECONDS', 1800);
        if ($defaultTtl <= 0) {
            $defaultTtl = 1800;
        }

        $paymentStatus = strtolower((string)($booking['payment_status'] ?? 'pending'));
        if ($paymentStatus === 'paid' || $paymentStatus === 'completed') {
            return $defaultTtl;
        }

        $expiresAt = $booking['reservation_expires_at'] ?? null;
        if (empty($expiresAt)) {
            return $defaultTtl;
        }

        $remaining = strtotime((string)$expiresAt) - time();
        if ($remaining <= 0) {
            return 60;
        }

        return min($defaultTtl, $remaining);
    }

    private function issueGuestAccessToken(array $booking): string
    {
        $reference = (string)($booking['booking_reference'] ?? '');
        $bookingId = (int)($booking['id'] ?? 0);
        if ($reference === '' || $bookingId <= 0) {
            throw new RuntimeException('Cannot issue access token for invalid booking');
        }

        $activeKey = "booking_access_active:{$reference}:{$bookingId}";
        $previousTokenHash = Cache::get($activeKey);
        if (is_string($previousTokenHash) && $previousTokenHash !== '') {
            Cache::delete("booking_access_session:{$previousTokenHash}");
        }

        $token = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $token);

        Cache::set("booking_access_session:{$tokenHash}", [
            'booking_id' => $bookingId,
            'reference' => $reference
        ], $this->getGuestAccessTokenTtlSeconds($booking));
        Cache::set($activeKey, $tokenHash, $this->getGuestAccessTokenTtlSeconds($booking));

        return $token;
    }

    private function validateGuestAccessToken(array $booking, string $accessToken): bool
    {
        $bookingId = (int)($booking['id'] ?? 0);
        $reference = (string)($booking['booking_reference'] ?? '');
        if ($bookingId <= 0 || $reference === '' || trim($accessToken) === '') {
            return false;
        }

        $tokenHash = hash('sha256', trim($accessToken));
        $activeTokenHash = Cache::get("booking_access_active:{$reference}:{$bookingId}");
        if (!is_string($activeTokenHash) || $activeTokenHash === '' || !hash_equals($activeTokenHash, $tokenHash)) {
            return false;
        }

        $session = Cache::get("booking_access_session:{$tokenHash}");
        if (!is_array($session)) {
            return false;
        }

        return (int)($session['booking_id'] ?? 0) === $bookingId
            && strtoupper((string)($session['reference'] ?? '')) === strtoupper($reference);
    }


    public function create() {
        // Authentication optional for bookings (guests can book)
        // $user_id = $this->authenticate();
        $data = request_json();

        // Support both old single-passenger and new multi-passenger formats
        $passengers = [];
        
        if (isset($data['passengers']) && is_array($data['passengers'])) {
            // New format: array of passengers
            $passengers = array_map(function($p) {
                // Combine first and last name if individual name property is missing
                if (!isset($p['name']) && isset($p['first_name']) && isset($p['last_name'])) {
                    $p['name'] = trim($p['first_name'] . ' ' . $p['last_name']);
                }
                return $p;
            }, $data['passengers']);
        } else if (isset($data['passenger_name'])) {
            // Old format: single passenger fields (backward compatibility)
            $passengers = [[
                'name' => $data['passenger_name'],
                'email' => $data['passenger_email'] ?? null,
                'contact' => $data['passenger_phone'] ?? null,
                'passenger_type' => $data['passenger_type'] ?? 'adult',
                'nationality' => $data['nationality'] ?? null,
                'identification' => $data['identification'] ?? null,
                'age' => $data['age'] ?? null,
                'title' => $data['title'] ?? null
            ]];
        }

        // Validate required fields
        if (empty($data['flight_series_id']) || empty($passengers) || empty($data['total_amount'])) {
            Response::json(['status' => false, 'message' => 'Missing required booking details'], 400);
            return;
        }

        // Securely fetch fares from DB to ensure integrity
        require_once __DIR__ . '/../models/Flight.php';
        $flightModel = new Flight(db());
        $flight = $flightModel->getById($data['flight_series_id']);
        
        if (!$flight) {
            Response::json(['status' => false, 'message' => 'Flight not found'], 404);
            return;
        }

        // Compute expected total server-side
        $expectedTotal = 0;
        foreach ($passengers as $p) {
            $type = strtolower($p['passenger_type'] ?? 'adult');
            $fare = (float)($flight[$type . '_fare'] ?? $flight['adult_fare']);
            $expectedTotal += $fare;
        }

        $clientTotal = (float)$data['total_amount'];
        $delta = abs($expectedTotal - $clientTotal);

        // Allow a tiny rounding difference (5%) for currency fluctuations if they ever occur, 
        // but generally should match exactly if using same currency.
        if ($delta > ($expectedTotal * 0.05)) {
            Response::json([
                'status' => false, 
                'message' => 'Price mismatch. The current fare for this flight has changed.',
                'details' => [
                    'expected' => $expectedTotal,
                    'received' => $clientTotal
                ]
            ], 400);
            return;
        }

        // Use the server-validated fare for the record
        $farePerPassenger = $expectedTotal / count($passengers);
        $numPassengers = count($passengers);

        // Start transaction
        $db = db();
        $db->beginTransaction();

        try {
            // Securely set user_id if token is present
            $headers = $this->readRequestHeaders();
            $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
            $authUserId = $this->userModel->validateToken($token);
            $userId = $authUserId ?: ($data['user_id'] ?? null);

            $primaryPassenger = $passengers[0];
            $bookingData = [
                'flight_series_id' => $data['flight_series_id'],
                'cabin_class_id' => $data['cabin_class_id'] ?? 1, // Defaulting to Economy if not provided
                'passenger_name' => $primaryPassenger['name'],
                'passenger_email' => $primaryPassenger['email'] ?? null,
                'passenger_phone' => $primaryPassenger['contact'] ?? null,
                'passenger_type' => $primaryPassenger['passenger_type'] ?? 'adult',
                'number_of_passengers' => $numPassengers,
                'fare_per_passenger' => $farePerPassenger,
                // Persist the server-computed canonical total, not arbitrary client value
                'total_amount' => $expectedTotal,
                'payment_method' => $data['payment_method'] ?? 'pending',
                'reservation_expires_at' => $this->bookingModel->reservationExpiresAt(),
                'notes' => $data['notes'] ?? null,
                'user_id' => $userId
            ];

            $bookingResponse = $this->bookingModel->create($bookingData);
            
            if (!$bookingResponse['status']) {
                throw new Exception($bookingResponse['message'] ?? 'Failed to create booking');
            }

            $bookingId = $bookingResponse['booking_id'];
            $bookingReference = $bookingResponse['reference'];

            // Create passengers and link to booking
            $createdPassengers = [];
            foreach ($passengers as $passengerData) {
                // Ensure name is set for models that expect a combined string
                if (empty($passengerData['name']) && !empty($passengerData['first_name']) && !empty($passengerData['last_name'])) {
                    $passengerData['name'] = trim($passengerData['first_name'] . ' ' . $passengerData['last_name']);
                }
                
                // Final fallback to avoid null if developer forgot both formats
                if (empty($passengerData['name'])) {
                    $passengerData['name'] = 'Guest Passenger';
                }

                // Create passenger record
                $passenger = $this->passengerModel->create([
                    'name' => $passengerData['name'],
                    'email' => $passengerData['email'] ?? null,
                    'contact' => $passengerData['contact'] ?? null,
                    'nationality' => $passengerData['nationality'] ?? null,
                    'identification' => $passengerData['identification'] ?? null,
                    'age' => $passengerData['age'] ?? null,
                    'title' => $passengerData['title'] ?? null
                ]);

                if (!$passenger) {
                    throw new Exception('Failed to create passenger');
                }

                // Link passenger to booking
                $fareAmount = $passengerData['fare_amount'] ?? $bookingData['fare_per_passenger'];
                $passengerType = $passengerData['passenger_type'] ?? 'adult';
                
                $linkCreated = $this->bookingPassengerModel->create(
                    $bookingId,
                    $passenger['id'],
                    $passengerType,
                    $fareAmount
                );

                if (!$linkCreated) {
                    throw new Exception('Failed to link passenger to booking');
                }

                $createdPassengers[] = [
                    'passenger_id' => $passenger['id'],
                    'pnr' => $passenger['pnr'],
                    'name' => $passenger['name'],
                    'email' => $passenger['email'],
                    'passenger_type' => $passengerType,
                    'fare_amount' => $fareAmount
                ];
            }

            // Commit transaction
            $db->commit();

            $bookingSnapshot = $this->bookingModel->getById((int)$bookingId);
            if ($bookingSnapshot) {
                $this->sendReservationHoldNotifications($bookingSnapshot);
            }

            // Return success response with all passenger details
            Response::json([
                'status' => true,
                'message' => 'Booking created successfully',
                'booking_id' => $bookingId,
                'reference' => $bookingReference,
                'reservation_expires_at' => $bookingResponse['data']['reservation_expires_at'] ?? $bookingData['reservation_expires_at'],
                'access_token' => $this->issueGuestAccessToken($bookingSnapshot ?: [
                    'id' => $bookingId,
                    'booking_reference' => $bookingReference,
                    'reservation_expires_at' => $bookingResponse['data']['reservation_expires_at'] ?? $bookingData['reservation_expires_at']
                ]),
                'data' => array_merge($bookingResponse['data'], [
                    'passengers' => $createdPassengers
                ])
            ]);

        } catch (Exception $e) {
            // Rollback transaction on error
            $db->rollBack();
            error_log("Booking creation error: " . $e->getMessage());
            Response::json([
                'status' => false,
                'message' => 'Failed to create booking: ' . $e->getMessage()
            ], 500);
        }
    }

    public function listByPassenger($passenger_id) {
        // Optional: Add authentication check
        $bookings = $this->bookingModel->getByPassenger($passenger_id);
        Response::json(['status' => true, 'data' => $bookings]);
    }

    public function listAll() {
        // Admin only - should add admin check
        $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
        $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;
        
        $bookings = $this->bookingModel->getAll($limit, $offset);
        Response::json([
            'status' => true, 
            'data' => $bookings,
            'count' => count($bookings)
        ]);
    }

    private function canAccessBooking(array $booking, string $reference): bool
    {
        $headers = $this->readRequestHeaders();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';

        // 1. Try JWT Auth
        $authUserId = $this->userModel->validateToken($token);
        $isAuthorized = ($authUserId && (int)$authUserId === (int)($booking['user_id'] ?? 0));

        // 2. Try OTP Access Token (X-Booking-Access-Token)
        if (!$isAuthorized) {
            $accessToken = $headers['X-Booking-Access-Token'] ?? '';
            if (!empty($accessToken)) {
                $isAuthorized = $this->validateGuestAccessToken($booking, $accessToken);
            }
        }

        return $isAuthorized;
    }

    private function readRequestHeaders(): array
    {
        if (function_exists('request_headers')) {
            $headers = request_headers();
            if (is_array($headers)) {
                return $headers;
            }
        }

        if (function_exists('apache_request_headers')) {
            $headers = apache_request_headers();
            if (is_array($headers)) {
                return $headers;
            }
        }

        if (function_exists('getallheaders')) {
            $headers = getallheaders();
            if (is_array($headers)) {
                return $headers;
            }
        }

        $headers = [];
        foreach ($_SERVER as $key => $value) {
            if (strpos($key, 'HTTP_') !== 0) {
                continue;
            }
            $name = str_replace('_', ' ', strtolower(substr($key, 5)));
            $name = str_replace(' ', '-', ucwords($name));
            $headers[$name] = $value;
        }

        return $headers;
    }

    private function isBookingExpired(array $booking): bool
    {
        return $this->bookingModel->isReservationExpired($booking);
    }

    private function sendReservationHoldNotifications(array $booking): void
    {
        $reference = (string)($booking['booking_reference'] ?? '');
        if ($reference === '') {
            return;
        }

        $passengerName = (string)($booking['passenger_name'] ?? 'Traveler');
        $email = trim((string)($booking['passenger_email'] ?? ''));
        $phone = trim((string)($booking['passenger_phone'] ?? ''));
        $expiresAt = (string)($booking['reservation_expires_at'] ?? '');
        $frontendUrl = rtrim((string)env('FRONTEND_URL', env('APP_URL', '')), '/');
        $manageUrl = $frontendUrl !== ''
            ? $frontendUrl . '/manage?reference=' . rawurlencode($reference) . '&email=' . rawurlencode($email)
            : '';
        $brandName = (string)env('MAIL_FROM_NAME', env('APP_NAME', 'Mc Aviation'));

        if ($email !== '') {
            require_once __DIR__ . '/../services/EmailService.php';
            $sentEmail = EmailService::getInstance()->sendReservationHold(
                $email,
                $passengerName,
                $reference,
                $expiresAt,
                $manageUrl
            );
            if (!$sentEmail) {
                error_log("Failed to send reservation hold email for booking {$reference}");
            }
        }

        if ($phone !== '') {
            require_once __DIR__ . '/../services/SmsService.php';
            $sms = SmsService::getInstance();
            if ($sms->isConfigured()) {
                $message = "{$brandName}: seats held for booking {$reference}";
                if ($expiresAt !== '') {
                    $message .= " until {$expiresAt}. ";
                } else {
                    $message .= ". ";
                }
                $message .= $manageUrl !== ''
                    ? "Resume payment: {$manageUrl}"
                    : "Use Manage Booking with your booking email to continue payment.";

                if (!$sms->send($phone, $message)) {
                    error_log("Failed to send reservation hold SMS for booking {$reference}");
                }
            }
        }
    }

    public function get($reference) {
        $booking = $this->bookingModel->getByReference($reference);
        
        if ($booking) {
            if ($this->isBookingExpired($booking)) {
                $this->bookingModel->expireBooking((int)$booking['id']);
                $booking = $this->bookingModel->getByReference($reference);
                if (!$booking) {
                    Response::fail(404, 'Booking not found', 'BOOKING_NOT_FOUND');
                    return;
                }
            }

            if (!$this->canAccessBooking($booking, $reference)) {
                Response::fail(
                    401,
                    'Unauthorized. Please use the "Manage Booking" flow to verify access via OTP.',
                    'BOOKING_ACCESS_DENIED'
                );
                return;
            }

            // Get passengers for this booking
            $passengers = $this->bookingPassengerModel->getByBookingId($booking['id']);
            $booking['passengers'] = $passengers;

            // Derive canonical states for frontend rendering
            $booking['payment_state'] = $this->derivePaymentState($booking);
            $booking['ticket_state'] = $this->deriveTicketState($booking, $passengers);
            $booking['booking_state'] = $this->deriveBookingState($booking);
            $booking['next_actions'] = $this->deriveNextActions($booking, $booking['payment_state'], $booking['ticket_state']);
            
            Response::json(['status' => true, 'data' => $booking]);
        } else {
            Response::fail(404, 'Booking not found', 'BOOKING_NOT_FOUND');
        }
    }
    
    public function listByUser() {
        // Securely get user_id from auth token
        $userId = $this->authenticate();
        
        $bookings = $this->bookingModel->getByUserId($userId);
        
        // Add passengers to each booking
        foreach ($bookings as &$booking) {
            $passengers = $this->bookingPassengerModel->getByBookingId($booking['id']);
            $booking['passengers'] = $passengers;
        }
        
        Response::json([
            'status' => true,
            'data' => $bookings,
            'count' => count($bookings)
        ]);
    }

    public function updatePayment() {
        $data = request_json();

        // Backward/forward compatible payloads:
        // - legacy: {booking_id, status, payment_method}
        // - frontend currently sends: {booking_reference, payment_status, payment_method}
        $bookingId = $data['booking_id'] ?? null;
        $bookingRef = $data['booking_reference'] ?? null;
        $status = $data['status'] ?? ($data['payment_status'] ?? null);
        $method = $data['payment_method'] ?? null;

        if (empty($bookingId) && !empty($bookingRef)) {
            $found = $this->bookingModel->getByReference(strtoupper(trim($bookingRef)));
            $bookingId = $found['id'] ?? null;
        }

        if (empty($bookingId) || empty($status)) {
            Response::fail(
                400,
                'Missing payment details (booking_id or booking_reference) and (status or payment_status)',
                'PAYMENT_UPDATE_MISSING_FIELDS'
            );
            return;
        }

        $booking = $this->bookingModel->getById((int)$bookingId);
        if (!$booking) {
            Response::fail(404, 'Booking not found', 'BOOKING_NOT_FOUND');
            return;
        }

        if (!$this->canAccessBooking($booking, (string)$booking['booking_reference'])) {
            Response::fail(
                401,
                'Unauthorized. Please verify booking access before updating payment details.',
                'BOOKING_ACCESS_DENIED'
            );
            return;
        }

        if ($this->isBookingExpired($booking)) {
            $this->bookingModel->expireBooking((int)$booking['id']);
            Response::fail(
                409,
                'This reservation has expired. Please search again to create a new booking.',
                'BOOKING_HOLD_EXPIRED'
            );
            return;
        }

        $normalizedStatus = strtolower(trim((string)$status));
        $normalizedMethod = strtolower(trim((string)($method ?? '')));

        // This route is only for traveler-facing "payment initiated / pending" flows
        // such as bank transfer instructions. Paid status must only come from a verified
        // gateway callback or an internal/admin settlement flow.
        if ($normalizedStatus !== 'pending') {
            Response::fail(
                403,
                'This endpoint can only mark a booking payment as pending.',
                'PAYMENT_STATUS_MUTATION_FORBIDDEN'
            );
            return;
        }

        $allowedMethods = ['bank_transfer', 'wire_transfer', 'bank'];
        if (!in_array($normalizedMethod, $allowedMethods, true)) {
            Response::fail(
                400,
                'Unsupported payment method for this endpoint',
                'PAYMENT_METHOD_UNSUPPORTED'
            );
            return;
        }

        $success = $this->bookingModel->updatePaymentStatus((int)$bookingId, 'pending', $normalizedMethod);

        if ($success) {
            Response::json(['status' => true, 'message' => 'Payment status updated to pending']);
        } else {
            error_log("Failed to update payment status for booking ID: " . ($bookingId ?? 'unknown'));
            Response::fail(500, 'Failed to update payment status', 'PAYMENT_UPDATE_FAILED');
        }
    }

    private function derivePaymentState(array $booking): string
    {
        $raw = strtolower((string)($booking['payment_status'] ?? 'pending'));
        if ($raw === 'paid' || $raw === 'completed') return 'PAID';
        if ($raw === 'failed' || $raw === 'cancelled') return 'FAILED';
        return 'PENDING';
    }

    private function deriveTicketState(array $booking, array $passengers): string
    {
        // TicketService sets bookings.status = 1 and fills booking_passengers.ticket_number
        $bookingStatus = (int)($booking['status'] ?? 0);
        if ($bookingStatus === 1) return 'TICKETED';

        foreach ($passengers as $p) {
            if (!empty($p['ticket_number'])) return 'TICKETED';
        }

        // If paid but not ticketed yet, treat as pending ticketing
        $paymentState = $this->derivePaymentState($booking);
        if ($paymentState === 'PAID') return 'PENDING';
        return 'NOT_STARTED';
    }

    private function deriveBookingState(array $booking): string
    {
        if ($this->isBookingExpired($booking)) return 'EXPIRED';

        $status = (int)($booking['status'] ?? 0);
        if ($status === 1) return 'CONFIRMED';
        // No explicit cancelled enum in schema; reserve 2 as cancelled if later introduced.
        if ($status === 2) return 'CANCELLED';
        return 'CREATED';
    }

    private function deriveNextActions(array $booking, string $paymentState, string $ticketState): array
    {
        $actions = [];

        if ($paymentState === 'PENDING') {
            $actions[] = ['type' => 'PAY', 'label' => 'Complete payment'];
        } elseif ($paymentState === 'FAILED') {
            $actions[] = ['type' => 'RETRY_PAYMENT', 'label' => 'Retry payment'];
            $actions[] = ['type' => 'CONTACT_SUPPORT', 'label' => 'Contact support'];
        } elseif ($paymentState === 'PAID' && $ticketState !== 'TICKETED') {
            $actions[] = ['type' => 'WAIT_TICKETING', 'label' => 'Ticketing in progress'];
            $actions[] = ['type' => 'CONTACT_SUPPORT', 'label' => 'Contact support'];
        } elseif ($paymentState === 'PAID' && $ticketState === 'TICKETED') {
            $actions[] = ['type' => 'DOWNLOAD_TICKET', 'label' => 'Download e-ticket'];
        }

        return $actions;
    }

    /**
     * ARCHITECTURAL GUARDRAILS (IATA DISTRIBUTION STANDARDS)
     * 
     * The following notes specify where critical GDS/Airline distribution logic
     * should reside in a production multi-channel environment:
     * 
     * 1. FARE REVALIDATION:
     *    Must occur immediately before payment capture. If the GDS quote 
     *    expires or shifts, the transaction must be aborted to prevent ADMs.
     * 
     * 2. PNR LIFECYCLE (TTL):
     *    A background worker/daemon must monitor 'pending' bookings. If not 
     *    ticketed within the Time-To-Limit (TTL) provided by the GDS, the 
     *    inventory must be released (Status: XX) to avoid "Inventory Spoilage" fines.
     * 
     * 3. TICKET VS ITINERARY:
     *    The 'Ticket' issued in TicketService is a legal document. Modification
     *    of PNR segments after issuance requires a Reissue or Exchange E-Ticket.
     */
    public function find() {
        // User must be authenticated to add a trip to their account
        $userId = $this->authenticate();
        $data = request_json();

        if (empty($data['reference']) || empty($data['last_name'])) {
            Response::json(['status' => false, 'message' => 'Missing reference or last name'], 400);
            return;
        }
        
        $reference = strtoupper(trim($data['reference']));
        $lastName = trim($data['last_name']);

        // 1. Find booking
        $booking = $this->bookingModel->getByReference($reference);
        if (!$booking) {
            Response::json(['status' => false, 'message' => 'Booking not found'], 404);
            return;
        }

        // 2. Verify Name Match (Case insensitive check if last name is part of passenger name)
        // Note: passenger_name in DB is "Title First Last" e.g., "Mr John Doe"
        if (stripos($booking['passenger_name'], $lastName) === false) {
             Response::json(['status' => false, 'message' => 'Booking found but name does not match.'], 403);
             return;
        }

        // 3. Link to User Account
        // Only link if not already linked OR if we allow re-linking (let's allow re-linking for now)
        $db = db();
        $stmt = $db->prepare("UPDATE bookings SET user_id = ? WHERE id = ?");
        $success = $stmt->execute([$userId, $booking['id']]);

        if ($success) {
            $booking['user_id'] = $userId; // Update local copy
             Response::json(['status' => true, 'message' => 'Trip found and added to your account', 'data' => $booking]);
        } else {
             Response::json(['status' => false, 'message' => 'Failed to link booking to account'], 500);
        }
    }

    /**
     * Public: request a one-time access code for a booking reference + email.
     * This is meant to replace insecure last-name substring matching.
     */
    public function requestAccessCode() {
        $data = request_json();
        $reference = strtoupper(trim((string)($data['reference'] ?? $data['booking_reference'] ?? '')));
        $email = strtolower(trim((string)($data['email'] ?? $data['passenger_email'] ?? '')));

        if (empty($reference) || empty($email)) {
            Response::fail(400, 'Missing reference or email', 'BOOKING_ACCESS_INPUT_INVALID');
            return;
        }

        // Basic IP rate limiting: 5 requests per 10 minutes per reference.
        $ip = client_ip();
        $rateKey = "booking_access_rl:" . $ip . ":" . $reference;
        $rate = Cache::get($rateKey);
        $count = is_array($rate) ? (int)($rate['count'] ?? 0) : 0;
        if ($count >= 5) {
            Response::fail(429, 'Too many requests. Try again later.', 'BOOKING_ACCESS_RATE_LIMITED');
            return;
        }
        Cache::set($rateKey, ['count' => $count + 1], 600);

        $booking = $this->bookingModel->getByReference($reference);
        if (!$booking) {
            // Avoid leaking whether a reference exists
            Response::json(['status' => true, 'message' => 'If the booking exists, a code has been sent.']);
            return;
        }

        $bookingEmail = strtolower(trim((string)($booking['passenger_email'] ?? '')));
        if (empty($bookingEmail) || $bookingEmail !== $email) {
            // Same non-leaky response
            Response::json(['status' => true, 'message' => 'If the booking exists, a code has been sent.']);
            return;
        }

        // Generate 6-digit code
        $code = (string)random_int(100000, 999999);
        $otpKey = "booking_access_otp:" . $reference . ":" . $email;
        Cache::set($otpKey, ['code' => $code], 600);

        require_once __DIR__ . '/../services/EmailService.php';
        $sentEmail = EmailService::getInstance()->sendBookingAccessCode(
            $bookingEmail,
            (string)($booking['passenger_name'] ?? 'Traveler'),
            $reference,
            $code
        );

        // Optional: also send SMS if a phone number exists and Twilio is configured.
        $sentSms = false;
        $phone = trim((string)($booking['passenger_phone'] ?? ''));
        if (!empty($phone)) {
            require_once __DIR__ . '/../services/SmsService.php';
            $sms = SmsService::getInstance();
            if ($sms->isConfigured()) {
                $msg = "Mc Aviation booking access code for {$reference}: {$code}. Expires in 10 minutes.";
                $sentSms = $sms->send($phone, $msg);
            }
        }

        // Consider it delivered if at least one channel succeeded.
        if (!$sentEmail && !$sentSms) {
            Response::fail(500, 'Failed to send access code. Try again later.', 'BOOKING_ACCESS_DELIVERY_FAILED');
            return;
        }

        Response::json(['status' => true, 'message' => 'Access code sent.']);
    }

    /**
     * Public: verify access code; returns minimal success so client can proceed.
     */
    public function verifyAccessCode() {
        $data = request_json();
        $reference = strtoupper(trim((string)($data['reference'] ?? $data['booking_reference'] ?? '')));
        $email = strtolower(trim((string)($data['email'] ?? $data['passenger_email'] ?? '')));
        $code = trim((string)($data['code'] ?? ''));

        if (empty($reference) || empty($email) || empty($code)) {
            Response::fail(400, 'Missing reference, email, or code', 'BOOKING_ACCESS_INPUT_INVALID');
            return;
        }

        $otpKey = "booking_access_otp:" . $reference . ":" . $email;
        $stored = Cache::get($otpKey);
        $storedCode = is_array($stored) ? (string)($stored['code'] ?? '') : '';

        if (empty($storedCode) || !hash_equals($storedCode, $code)) {
            Response::fail(403, 'Invalid or expired code', 'BOOKING_ACCESS_CODE_INVALID');
            return;
        }

        // One-time use
        Cache::delete($otpKey);

        $booking = $this->bookingModel->getByReference($reference);
        if (!$booking) {
            Response::fail(404, 'Booking not found', 'BOOKING_NOT_FOUND');
            return;
        }

        $accessToken = $this->issueGuestAccessToken($booking);

        Response::json([
            'status' => true, 
            'message' => 'Verified',
            'access_token' => $accessToken
        ]);
    }

    public function expireStale() {
        $expired = $this->bookingModel->expireStaleReservations();
        Response::json([
            'status' => true,
            'message' => 'Stale reservations processed',
            'expired_count' => $expired
        ]);
    }

    /**
     * Public: retrieve booking documents.
     * GET /bookings/{reference}/documents?type=ticket|receipt|combined&format=html|json|pdf&currency=USD|KES|...
     */
    public function documents($reference) {
        $reference = strtoupper(trim((string)$reference));
        $type = strtolower((string)($_GET['type'] ?? 'combined'));
        $format = strtolower((string)($_GET['format'] ?? 'html'));
        $displayCurrency = strtoupper(trim((string)($_GET['currency'] ?? 'USD')));

        if (!preg_match('/^[A-Z]{3}$/', $displayCurrency)) {
            Response::fail(400, 'Invalid currency code', 'CURRENCY_INVALID');
            return;
        }

        $booking = $this->bookingModel->getByReference($reference);
        if (!$booking) {
            Response::fail(404, 'Booking not found', 'BOOKING_NOT_FOUND');
            return;
        }

        if (!$this->canAccessBooking($booking, $reference)) {
            Response::fail(
                401,
                'Unauthorized. Please use the "Manage Booking" flow to verify access via OTP.',
                'BOOKING_ACCESS_DENIED'
            );
            return;
        }

        if ($this->isBookingExpired($booking)) {
            $this->bookingModel->expireBooking((int)$booking['id']);
            Response::fail(
                409,
                'This reservation has expired and documents are no longer available for this pending booking.',
                'BOOKING_HOLD_EXPIRED'
            );
            return;
        }

        $passengers = $this->bookingPassengerModel->getByBookingId($booking['id']);

        // System base currency is USD. Convert only for document display.
        $currencyConversionError = null;
        [$bookingForDoc, $passengersForDoc] = $this->convertBookingAndPassengersForDisplay(
            $booking,
            $passengers,
            'USD',
            $displayCurrency,
            $currencyConversionError
        );

        if ($currencyConversionError !== null) {
            Response::fail(
                503,
                'Could not convert document currency right now',
                'CURRENCY_CONVERSION_UNAVAILABLE',
                ['reason' => $currencyConversionError]
            );
            return;
        }

        require_once __DIR__ . '/../services/TicketService.php';
        $ticketService = TicketService::getInstance();

        $ticketHtml = $ticketService->generateTicketHTML($bookingForDoc, $passengersForDoc);
        $receiptHtml = $ticketService->generateReceiptHTML($bookingForDoc, $passengersForDoc);

        if ($type === 'ticket') $html = $ticketHtml;
        else if ($type === 'receipt') $html = $receiptHtml;
        else {
            $html = "
                <div style='background-color: #f4f4f4; padding: 20px 0;'>
                    {$ticketHtml}
                    <div style='margin: 40px 0; border-top: 2px dashed #ccc;'></div>
                    {$receiptHtml}
                </div>
            ";
        }

        if ($format === 'json') {
            Response::json([
                'status' => true,
                'data' => [
                    'reference' => $reference,
                    'type' => $type,
                    'currency' => $displayCurrency,
                    'html' => $html
                ]
            ]);
            return;
        }

        if ($format === 'pdf') {
            $htmlForPdf = $this->buildDocumentHtmlForPdf($type, $ticketHtml, $receiptHtml);
            $autoload = __DIR__ . '/../vendor/autoload.php';
            if (!is_file($autoload)) {
                Response::fail(
                    503,
                    'PDF generation is not configured. Run composer install in the API directory.',
                    'PDF_NOT_CONFIGURED'
                );
                return;
            }
            require_once $autoload;
            try {
                $options = new \Dompdf\Options();
                $options->set('isRemoteEnabled', true);
                $options->set('defaultFont', 'DejaVu Sans');
                $dompdf = new \Dompdf\Dompdf($options);
                $dompdf->loadHtml($htmlForPdf, 'UTF-8');
                $dompdf->setPaper('A4', 'portrait');
                $dompdf->render();
                header('Content-Type: application/pdf');
                header('Content-Disposition: inline; filename="Airlogix-E-Ticket-' . $reference . '.pdf"');
                echo $dompdf->output();
            } catch (\Throwable $e) {
                error_log('PDF generation failed: ' . $e->getMessage());
                Response::fail(500, 'Could not generate PDF', 'PDF_GENERATION_FAILED');
            }
            return;
        }

        header('Content-Type: text/html; charset=utf-8');
        echo $html;
    }

    /**
     * Build a single valid HTML document for PDF rendering (avoids nested full documents in combined view).
     */
    private function buildDocumentHtmlForPdf($type, $ticketHtml, $receiptHtml) {
        $type = strtolower((string)$type);
        if ($type === 'ticket') {
            return $ticketHtml;
        }
        if ($type === 'receipt') {
            return '<!DOCTYPE html><html><head><meta charset="UTF-8"><style>body{margin:0;padding:0;background:#f4f4f4;}</style></head><body>'
                . $receiptHtml
                . '</body></html>';
        }
        $ticketInner = $this->extractBodyInnerHtml($ticketHtml);
        return '<!DOCTYPE html><html><head><meta charset="UTF-8"><style>body{margin:0;padding:0;background:#f4f4f4;}</style></head><body>'
            . '<div style="background-color:#f4f4f4;padding:20px 0;">'
            . $ticketInner
            . '<div style="margin:40px 0;border-top:2px dashed #ccc;"></div>'
            . $receiptHtml
            . '</div></body></html>';
    }

    private function extractBodyInnerHtml($html) {
        if (preg_match('/<body[^>]*>(.*)<\/body>/is', $html, $m)) {
            return trim($m[1]);
        }
        return $html;
    }

    /**
     * Convert booking/passenger monetary fields for document display only.
     */
    private function convertBookingAndPassengersForDisplay(
        array $booking,
        array $passengers,
        string $sourceCurrency,
        string $targetCurrency,
        ?string &$error = null
    ): array {
        $sourceCurrency = strtoupper(trim($sourceCurrency));
        $targetCurrency = strtoupper(trim($targetCurrency));

        $booking['currency'] = $targetCurrency;

        if ($sourceCurrency === $targetCurrency) {
            return [$booking, $passengers];
        }

        $factor = $this->getCurrencyConversionFactor($sourceCurrency, $targetCurrency, $error);
        if ($factor === null) {
            return [$booking, $passengers];
        }

        if (isset($booking['total_amount'])) {
            $booking['total_amount'] = round((float)$booking['total_amount'] * $factor, 2);
        }
        if (isset($booking['fare_per_passenger'])) {
            $booking['fare_per_passenger'] = round((float)$booking['fare_per_passenger'] * $factor, 2);
        }

        foreach ($passengers as &$p) {
            if (isset($p['fare_amount'])) {
                $p['fare_amount'] = round((float)$p['fare_amount'] * $factor, 2);
            }
        }
        unset($p);

        return [$booking, $passengers];
    }

    /**
     * Exchange rates table stores values relative to Fixer base EUR.
     */
    private function getCurrencyConversionFactor(string $fromCurrency, string $toCurrency, ?string &$error = null): ?float
    {
        try {
            $db = db();
            $stmt = $db->prepare("SELECT currency_code, rate FROM exchange_rates WHERE currency_code IN (?, ?)");
            $stmt->execute([$fromCurrency, $toCurrency]);

            $rates = [];
            while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
                $rates[$row['currency_code']] = (float)$row['rate'];
            }

            if (!isset($rates[$fromCurrency]) || !isset($rates[$toCurrency])) {
                $error = "Missing exchange rates for {$fromCurrency} or {$toCurrency}";
                return null;
            }

            $amountInBaseEur = 1 / $rates[$fromCurrency];
            return $amountInBaseEur * $rates[$toCurrency];
        } catch (Throwable $e) {
            $error = 'Rate lookup failed: ' . $e->getMessage();
            return null;
        }
    }
}
?>
