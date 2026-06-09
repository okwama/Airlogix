<?php
/**
 * Shared booking access, FX, idempotent fulfillment, and notifications for all payment gateways.
 */
require_once dirname(__DIR__, 2) . '/config.php';
require_once dirname(__DIR__, 2) . '/models/Payment.php';
require_once dirname(__DIR__, 2) . '/models/Booking.php';
require_once dirname(__DIR__, 2) . '/models/BookingPassenger.php';
require_once dirname(__DIR__, 2) . '/models/AirlineUser.php';
require_once dirname(__DIR__, 2) . '/models/Loyalty.php';
require_once dirname(__DIR__, 2) . '/models/Notification.php';
require_once dirname(__DIR__, 2) . '/services/NotificationDeliveryService.php';
require_once dirname(__DIR__, 2) . '/utils/Response.php';
require_once dirname(__DIR__, 2) . '/utils/Cache.php';
require_once dirname(__DIR__, 2) . '/utils/Observability.php';
require_once dirname(__DIR__, 2) . '/models/JournalEntry.php';

abstract class PaymentControllerBase
{
    protected $paymentModel;
    protected $bookingModel;
    protected $userModel;

    public function __construct()
    {
        $db = db();
        $this->paymentModel = new Payment($db);
        $this->bookingModel = new Booking($db);
        $this->userModel = new AirlineUser($db);
    }

    protected function authenticate()
    {
        $headers = request_headers();
        $authHeader = $this->headerValue($headers, 'Authorization') ?? '';
        $token = stripos($authHeader, 'Bearer ') === 0 ? trim(substr($authHeader, 7)) : '';
        $user_id = $this->userModel->validateToken($token);

        if (!$user_id) {
            Response::fail(401, 'Unauthorized', 'AUTH_UNAUTHORIZED');
            exit();
        }
        return $user_id;
    }

    protected function canAccessBooking(array $booking): bool
    {
        $headers = request_headers();
        $authHeader = $this->headerValue($headers, 'Authorization') ?? '';
        $token = stripos($authHeader, 'Bearer ') === 0 ? trim(substr($authHeader, 7)) : '';

        $authUserId = $this->userModel->validateToken($token);
        $isAuthorized = ($authUserId && (int)$authUserId === (int)($booking['user_id'] ?? 0));

        if (!$isAuthorized) {
            $accessToken = (string)($this->headerValue($headers, 'X-Booking-Access-Token') ?? '');
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

    protected function headerValue(array $headers, string $name): ?string
    {
        if (isset($headers[$name])) {
            return (string)$headers[$name];
        }
        $lower = strtolower($name);
        foreach ($headers as $k => $v) {
            if (strtolower((string)$k) === $lower) {
                return (string)$v;
            }
        }
        return null;
    }

    protected function ensureActiveReservation(array $booking): void
    {
        if ($this->bookingModel->isReservationExpired($booking)) {
            $this->bookingModel->expireBooking((int)$booking['id']);
            Response::fail(
                409,
                'This reservation has expired. Please search again to create a new booking.',
                'BOOKING_HOLD_EXPIRED'
            );
            exit();
        }
    }

    protected function convertAmount($amount, $fromCurrency, $toCurrency)
    {
        if ($fromCurrency === $toCurrency) {
            return $amount;
        }

        $db = db();
        $stmt = $db->prepare('SELECT currency_code, rate FROM exchange_rates WHERE currency_code IN (?, ?)');
        $stmt->execute([$fromCurrency, $toCurrency]);
        $rates = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $rates[$row['currency_code']] = (float)$row['rate'];
        }

        if (!isset($rates[$fromCurrency]) || !isset($rates[$toCurrency])) {
            error_log("Conversion failed: missing rates for $fromCurrency or $toCurrency");
            return $amount;
        }

        $amountInBase = $amount / $rates[$fromCurrency];
        return $amountInBase * $rates[$toCurrency];
    }

    protected function callbackCacheKey(string $method, string $gatewayReference): string
    {
        return 'payment_callback_done:' . strtolower(trim($method)) . ':' . hash('sha256', trim($gatewayReference));
    }

    protected function isCallbackAlreadyProcessed(string $method, ?string $gatewayReference): bool
    {
        $ref = trim((string)$gatewayReference);
        if ($ref === '') {
            return false;
        }
        return Cache::get($this->callbackCacheKey($method, $ref)) === true;
    }

    protected function markCallbackProcessed(string $method, ?string $gatewayReference): void
    {
        $ref = trim((string)$gatewayReference);
        if ($ref === '') {
            return;
        }
        Cache::set($this->callbackCacheKey($method, $ref), true, 30 * 24 * 60 * 60);
    }

    protected function issueGuestAccessTokenForBooking(array $booking): string
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

    protected function finalizeSuccessfulPayment(array $booking, string $method, ?string $gatewayReference = null, array $gatewayPayload = []): void
    {
        if (empty($booking['id'])) {
            return;
        }

        $gatewayReference = trim((string)$gatewayReference);
        $method = strtolower(trim($method));

        if ($gatewayReference !== '' && $this->isCallbackAlreadyProcessed($method, $gatewayReference)) {
            Observability::event('payment.callback_replay_ignored', [
                'booking_id' => (int)($booking['id'] ?? 0),
                'booking_reference' => (string)($booking['booking_reference'] ?? ''),
                'method' => $method,
                'gateway_reference' => $gatewayReference
            ]);
            return;
        }

        $existingTrace = null;
        if ($gatewayReference !== '') {
            $existingTrace = $this->paymentModel->findByGatewayReference($gatewayReference, $method);
            if (
                is_array($existingTrace)
                && (($existingTrace['status'] ?? '') === 'completed')
                && (($booking['payment_status'] ?? null) === 'paid')
            ) {
                $this->markCallbackProcessed($method, $gatewayReference);
                Observability::event('payment.callback_replay_ignored', [
                    'booking_id' => (int)($booking['id'] ?? 0),
                    'booking_reference' => (string)($booking['booking_reference'] ?? ''),
                    'method' => $method,
                    'gateway_reference' => $gatewayReference
                ]);
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
            Observability::event('payment.callback_postpaid_received', [
                'booking_id' => (int)($booking['id'] ?? 0),
                'booking_reference' => (string)($booking['booking_reference'] ?? ''),
                'method' => $method,
                'gateway_reference' => $gatewayReference
            ]);
            return;
        }

        $paymentAccount = null;
        if (isset($gatewayPayload['phone'])) {
            $paymentAccount = $gatewayPayload['phone'];
        } elseif (isset($gatewayPayload['phone_number'])) {
            $paymentAccount = $gatewayPayload['phone_number'];
        } elseif (isset($gatewayPayload['PhoneNumber'])) {
            $paymentAccount = $gatewayPayload['PhoneNumber'];
        } elseif (isset($gatewayPayload['customerPhone'])) {
            $paymentAccount = $gatewayPayload['customerPhone'];
        } elseif (isset($gatewayPayload['account'])) {
            $paymentAccount = $gatewayPayload['account'];
        }

        // Authoritative payment confirmation: gateway callbacks MUST call
        // `updatePaymentStatus(..., 'paid', $method, $gatewayReference, $account)`
        // only after verifying the provider's signature/notification and
        // ensuring idempotency. This prevents fraud and duplicate postings.
        $updatedRows = $this->bookingModel->updatePaymentStatus(
            $booking['id'],
            'paid',
            $method,
            $gatewayReference,
            $paymentAccount
        );
        if ($updatedRows === 0) {
            Observability::event('payment.booking_not_updated', [
                'booking_id' => $booking['id'] ?? null,
                'booking_reference' => $booking['booking_reference'] ?? null,
                'method' => $method,
                'gateway_reference' => $gatewayReference
            ]);
        } else {
            Observability::event('payment.booking_updated', [
                'booking_id' => $booking['id'] ?? null,
                'booking_reference' => $booking['booking_reference'] ?? null,
                'rows_affected' => $updatedRows
            ]);
        }

        // Best-effort GL posting: create a JournalEntry for the received payment
        try {
            $jeModel = new JournalEntry(db());
            $jeModel->create([
                'booking_reference' => $booking['booking_reference'] ?? null,
                'amount' => $booking['total_amount'] ?? 0.00,
                    'payment_method' => $method,
                    'currency' => $booking['currency'] ?? 'USD',
                    'entry_date' => date('Y-m-d')
            ]);
        } catch (Throwable $jeErr) {
            error_log('JournalEntry create failed: ' . $jeErr->getMessage());
            Observability::event('payment.gl_posting_failed', [
                'booking_id' => (int)($booking['id'] ?? 0),
                'booking_reference' => (string)($booking['booking_reference'] ?? ''),
                'error_message' => Observability::sanitiseError($jeErr)
            ]);
            // Do not abort payment finalization; GL posting is best-effort
        }

        // Update seat_reservations to 'booked' when payment is confirmed
        try {
            $db = db();
            $stmt = $db->prepare("
                UPDATE seat_reservations 
                SET status = 'booked', 
                    payment_status = 'paid', 
                    amount_paid = ?, 
                    updated_at = NOW() 
                WHERE booking_reference = ?
            ");
            $stmt->execute([
                $booking['total_amount'],
                $booking['booking_reference']
            ]);
        } catch (Throwable $seError) {
            error_log("Failed to update seat reservation status: " . $seError->getMessage());
        }

        // Update booking_passengers payment details
        try {
            $db = db();
            $stmtBP = $db->prepare("
                UPDATE booking_passengers 
                SET payment_reference = ?,
                    payment_account = ?
                WHERE booking_id = ?
            ");
            $stmtBP->execute([
                $gatewayReference !== '' ? $gatewayReference : null,
                $paymentAccount,
                $booking['id']
            ]);
        } catch (Throwable $bpError) {
            error_log("Failed to update booking_passengers payment info: " . $bpError->getMessage());
        }

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

        // Log/createGatewayTrace result for diagnostics
        Observability::event('payment.gateway_trace_created', [
            'booking_id' => (int)($booking['id'] ?? 0),
            'booking_reference' => (string)($booking['booking_reference'] ?? ''),
            'gateway_reference' => $gatewayReference,
            'trace_result' => is_array($transactionResult) ? $transactionResult : null
        ]);

        $traceId = !empty($transactionResult['transaction_id']) ? (int)$transactionResult['transaction_id'] : 0;
        // If createGatewayTrace didn't return an internal id, try to resolve it
        if ($traceId === 0) {
            try {
                if (!empty($gatewayReference)) {
                    $found = $this->paymentModel->findByGatewayReference($gatewayReference, $method);
                    if (is_array($found) && !empty($found['id'])) {
                        $traceId = (int)$found['id'];
                    }
                }
            } catch (Throwable $lookupErr) {
                error_log('Failed to lookup existing gateway trace by reference: ' . $lookupErr->getMessage());
            }

            if ($traceId === 0) {
                try {
                    $list = $this->paymentModel->getByBooking($booking['id']);
                    if (is_array($list) && count($list) > 0 && !empty($list[0]['id'])) {
                        $traceId = (int)$list[0]['id'];
                    }
                } catch (Throwable $listErr) {
                    error_log('Failed to lookup gateway trace by booking: ' . $listErr->getMessage());
                }
            }
        }

        if ($traceId > 0) {
            $ok = $this->paymentModel->updateStatus(
                $traceId,
                'completed',
                $gatewayReference !== '' ? $gatewayReference : ($booking['booking_reference'] ?? null),
                json_encode($traceMetadata)
            );
            if (!$ok) {
                error_log('Payment::updateStatus failed for trace_id=' . $traceId);
                Observability::event('payment.update_status_failed', [
                    'trace_id' => $traceId,
                    'booking_id' => $booking['id'] ?? null
                ]);
            }
        } else {
            Observability::event('payment.gateway_trace_missing_id', [
                'booking_id' => $booking['id'] ?? null,
                'booking_reference' => $booking['booking_reference'] ?? null,
                'gateway_reference' => $gatewayReference
            ]);
        }
        try {
            $db = db();
            $stmt = $db->prepare("\
                UPDATE seat_reservations 
                SET status = 'booked', 
                    payment_status = 'paid', 
                    amount_paid = ?, 
                    updated_at = NOW() 
                WHERE booking_reference = ?
            ");
            $stmt->execute([
                $booking['total_amount'],
                $booking['booking_reference']
            ]);
            if ($stmt->rowCount() === 0) {
                Observability::event('payment.seat_reservations_not_updated', [
                    'booking_id' => $booking['id'] ?? null,
                    'booking_reference' => $booking['booking_reference'] ?? null
                ]);
            } else {
                Observability::event('payment.seat_reservations_updated', [
                    'booking_id' => $booking['id'] ?? null,
                    'booking_reference' => $booking['booking_reference'] ?? null,
                    'rows_affected' => $stmt->rowCount()
                ]);
            }
        } catch (Throwable $seError) {
            error_log("Failed to update seat reservation status: " . $seError->getMessage());
        }
        $this->markCallbackProcessed($method, $gatewayReference);
        Observability::event('payment.success', [
            'booking_id' => (int)$booking['id'],
            'booking_reference' => (string)($booking['booking_reference'] ?? ''),
            'user_id' => $booking['user_id'] ?? null,
            'method' => $method,
            'gateway_reference' => $gatewayReference,
            'amount' => (float)($booking['total_amount'] ?? 0),
            'currency' => (string)($booking['currency'] ?? 'USD')
        ]);
        try {
            $db = db();
            $stmtBP = $db->prepare("\
                UPDATE booking_passengers 
                SET payment_reference = ?,
                    payment_account = ?
                WHERE booking_id = ?
            ");
            $stmtBP->execute([
                $gatewayReference !== '' ? $gatewayReference : null,
                $paymentAccount,
                $booking['id']
            ]);
            if ($stmtBP->rowCount() === 0) {
                Observability::event('payment.booking_passengers_not_updated', [
                    'booking_id' => $booking['id'] ?? null,
                    'booking_reference' => $booking['booking_reference'] ?? null
                ]);
            } else {
                Observability::event('payment.booking_passengers_updated', [
                    'booking_id' => $booking['id'] ?? null,
                    'booking_reference' => $booking['booking_reference'] ?? null,
                    'rows_affected' => $stmtBP->rowCount()
                ]);
            }
        } catch (Throwable $bpError) {
            error_log("Failed to update booking_passengers payment info: " . $bpError->getMessage());
        }
        // Prepare notification context
        $userId = (int)($booking['user_id'] ?? 0);
        $reference = (string)($booking['booking_reference'] ?? '');
        $title = 'Payment successful';
        $message = $reference !== ''
            ? "Payment received for booking {$reference}. Your seats are now confirmed."
            : 'Payment received. Your seats are now confirmed.';

        try {
            $notification = new Notification(db());
            $notification->create($userId, 'flight', $title, $message);

            $delivery = new NotificationDeliveryService(db());
            if ($delivery->isConfigured()) {
                $delivery->sendPushToUser(
                    $userId,
                    $title,
                    $message,
                    [
                        'type' => 'flight',
                        'booking_reference' => $reference,
                        'booking_id' => (int)($booking['id'] ?? 0),
                        'event' => 'payment_success',
                        'payment_method' => strtolower(trim($method)),
                    ]
                );
            }
        } catch (Throwable $notifyError) {
            error_log('Failed to send payment success notification: ' . $notifyError->getMessage());
        }
    }

    protected function notifyPaymentFailed(array $booking, string $method, ?string $gatewayMessage = null): void
    {
        $userId = (int)($booking['user_id'] ?? 0);
        if ($userId <= 0) {
            return;
        }

        $reference = (string)($booking['booking_reference'] ?? '');
        $title = 'Payment unsuccessful';
        $message = $reference !== ''
            ? "We couldn't complete payment for booking {$reference}. Please try again."
            : "We couldn't complete your booking payment. Please try again.";

        if ($gatewayMessage !== null && trim($gatewayMessage) !== '') {
            $message .= ' ' . trim($gatewayMessage);
        }

        try {
            $notification = new Notification(db());
            $notification->create($userId, 'flight', $title, $message);

            $delivery = new NotificationDeliveryService(db());
            if ($delivery->isConfigured()) {
                $delivery->sendPushToUser(
                    $userId,
                    $title,
                    $message,
                    [
                        'type' => 'flight',
                        'booking_reference' => $reference,
                        'booking_id' => (int)($booking['id'] ?? 0),
                        'event' => 'payment_failed',
                        'payment_method' => strtolower(trim($method)),
                    ]
                );
            }
        } catch (Throwable $notifyError) {
            error_log('Failed to send payment failure notification: ' . $notifyError->getMessage());
        }
    }
}
