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
        $headers = apache_request_headers();
        $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::json(['status' => false, 'message' => 'Unauthorized'], 401);
            exit();
        }
        return $user_id;
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

        // Start transaction
        $db = db();
        $db->beginTransaction();

        try {
            // Securely set user_id if token is present
            $headers = apache_request_headers();
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

            // Return success response with all passenger details
            Response::json([
                'status' => true,
                'message' => 'Booking created successfully',
                'booking_id' => $bookingId,
                'reference' => $bookingReference,
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


    public function get($reference) {
        $booking = $this->bookingModel->getByReference($reference);
        
        if ($booking) {
            // SECURITY: Require authentication or a valid access token
            $headers = apache_request_headers();
            $token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';
            
            // 1. Try JWT Auth
            $authUserId = $this->userModel->validateToken($token);
            $isAuthorized = ($authUserId && (int)$authUserId === (int)$booking['user_id']);
            
            // 2. Try OTP Access Token (X-Booking-Access-Token)
            if (!$isAuthorized) {
                $accessToken = $headers['X-Booking-Access-Token'] ?? '';
                if (!empty($accessToken)) {
                    $expected = hash_hmac('sha256', $reference . '|' . $booking['id'], env('JWT_SECRET', 'airlogix_default_secret'));
                    $isAuthorized = hash_equals($expected, $accessToken);
                }
            }

            if (!$isAuthorized) {
                Response::json([
                    'status' => false, 
                    'message' => 'Unauthorized. Please use the "Manage Booking" flow to verify access via OTP.'
                ], 401);
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
            Response::json(['status' => false, 'message' => 'Booking not found'], 404);
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
            Response::json(['status' => false, 'message' => 'Missing payment details (booking_id or booking_reference) and (status or payment_status)'], 400);
            return;
        }

        $success = $this->bookingModel->updatePaymentStatus((int)$bookingId, $status, $method);

        if ($success) {
            // Trigger Ticket Issuance if status is PAID
            if ($status === 'paid') {
                require_once __DIR__ . '/../services/TicketService.php';
                TicketService::getInstance()->issueTickets((int)$bookingId);
                
                $booking = $this->bookingModel->getById((int)$bookingId);
                
                if ($booking) {
                    // Fetch passengers for the ticket
                    $passengers = $this->bookingPassengerModel->getByBookingId((int)$bookingId);
                    
                    // Sending combined e-ticket & receipt
                    $sent = TicketService::getInstance()->sendTicket($booking, $passengers);
                    if (!$sent) {
                        error_log("Payment marked as PAID but document delivery failed for Ref: " . $booking['booking_reference']);
                    }
                    
                    // Award Loyalty Points if user is logged in
                    if (!empty($booking['user_id'])) {
                        require_once __DIR__ . '/LoyaltyController.php'; // Ensure loyalty model/logic is accessible
                        $loyalty = new Loyalty(db());
                        $loyalty->awardPoints($booking['user_id'], $booking['id'], $booking['total_amount']);
                    }
                } else {
                    error_log("Severe: Payment marked as PAID for non-existent booking ID: " . $bookingId);
                }
            }
            
            Response::json(['status' => true, 'message' => 'Payment status updated and tickets issued']);
        } else {
            error_log("Failed to update payment status for booking ID: " . ($bookingId ?? 'unknown'));
            Response::json(['status' => false, 'message' => 'Failed to update payment status'], 500);
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
            Response::json(['status' => false, 'message' => 'Missing reference or email'], 400);
            return;
        }

        // Basic IP rate limiting: 5 requests per 10 minutes per reference.
        $ip = client_ip();
        $rateKey = "booking_access_rl:" . $ip . ":" . $reference;
        $rate = Cache::get($rateKey);
        $count = is_array($rate) ? (int)($rate['count'] ?? 0) : 0;
        if ($count >= 5) {
            Response::json(['status' => false, 'message' => 'Too many requests. Try again later.'], 429);
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
            Response::json(['status' => false, 'message' => 'Failed to send access code. Try again later.'], 500);
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
            Response::json(['status' => false, 'message' => 'Missing reference, email, or code'], 400);
            return;
        }

        $otpKey = "booking_access_otp:" . $reference . ":" . $email;
        $stored = Cache::get($otpKey);
        $storedCode = is_array($stored) ? (string)($stored['code'] ?? '') : '';

        if (empty($storedCode) || !hash_equals($storedCode, $code)) {
            Response::json(['status' => false, 'message' => 'Invalid or expired code'], 403);
            return;
        }

        // One-time use
        Cache::delete($otpKey);

        // Generate a temporary access token for this browser session
        $booking = $this->bookingModel->getByReference($reference);
        $accessToken = hash_hmac('sha256', $reference . '|' . $booking['id'], env('JWT_SECRET', 'airlogix_default_secret'));

        Response::json([
            'status' => true, 
            'message' => 'Verified',
            'access_token' => $accessToken
        ]);
    }

    /**
     * Public: retrieve booking documents.
     * GET /bookings/{reference}/documents?type=ticket|receipt|combined&format=html|json|pdf
     */
    public function documents($reference) {
        $reference = strtoupper(trim((string)$reference));
        $type = strtolower((string)($_GET['type'] ?? 'combined'));
        $format = strtolower((string)($_GET['format'] ?? 'html'));

        $booking = $this->bookingModel->getByReference($reference);
        if (!$booking) {
            Response::json(['status' => false, 'message' => 'Booking not found'], 404);
            return;
        }

        $passengers = $this->bookingPassengerModel->getByBookingId($booking['id']);

        require_once __DIR__ . '/../services/TicketService.php';
        $ticketService = TicketService::getInstance();

        $ticketHtml = $ticketService->generateTicketHTML($booking, $passengers);
        $receiptHtml = $ticketService->generateReceiptHTML($booking, $passengers);

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
                    'html' => $html
                ]
            ]);
            return;
        }

        if ($format === 'pdf') {
            $htmlForPdf = $this->buildDocumentHtmlForPdf($type, $ticketHtml, $receiptHtml);
            $autoload = __DIR__ . '/../vendor/autoload.php';
            if (!is_file($autoload)) {
                Response::json(['status' => false, 'message' => 'PDF generation is not configured. Run composer install in the API directory.'], 503);
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
                Response::json(['status' => false, 'message' => 'Could not generate PDF'], 500);
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
}
?>
