<?php

require_once __DIR__ . '/PaymentControllerBase.php';

final class StripePaymentController extends PaymentControllerBase
{
    public function initializeStripe(): void
    {
        $data = request_json();

        if (empty($data['booking_reference']) || empty($data['email'])) {
            Response::fail(400, 'Missing required payment details', 'PAYMENT_INIT_MISSING_FIELDS');
            return;
        }
        $email = trim((string)$data['email']);
        if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            Response::fail(400, 'A valid email is required for Stripe payment', 'PAYMENT_EMAIL_INVALID');
            return;
        }

        $booking = $this->bookingModel->getByReference($data['booking_reference']);
        if (!$booking) {
            Response::fail(404, 'Booking not found', 'BOOKING_NOT_FOUND');
            return;
        }

        if (!$this->canAccessBooking($booking)) {
            Response::fail(401, 'Unauthorized booking access', 'BOOKING_ACCESS_DENIED');
            return;
        }
        $this->ensureActiveReservation($booking);

        if (($booking['payment_status'] ?? null) === 'paid') {
            Response::fail(409, 'Booking is already marked as paid', 'BOOKING_ALREADY_PAID');
        }

        $currency = strtoupper((string)($data['currency'] ?? 'USD'));
        $amount = (float)($booking['total_amount'] ?? 0);
        if ($amount <= 0) {
            Response::fail(400, 'Booking has invalid total amount', 'BOOKING_AMOUNT_INVALID');
            return;
        }

        $convertedAmount = $currency === 'USD'
            ? $amount
            : $this->convertAmount($amount, 'USD', $currency);

        require_once dirname(__DIR__, 2) . '/services/StripeService.php';
        $stripe = new StripeService();

        $clientChannel = strtolower(trim((string)($data['channel'] ?? 'web')));

        $response = $stripe->createCheckoutSession(
            $convertedAmount,
            $currency,
            $booking['booking_reference'],
            $email,
            $clientChannel
        );
        if (($response['status'] ?? false) === true) {
            $this->bookingModel->updatePaymentStatus(
                $booking['id'],
                'pending',
                'stripe'
            );

            $this->paymentModel->initiate([
                'booking_id' => $booking['id'],
                'user_id' => $booking['user_id'] ?? null,
                'amount' => $amount,
                'currency' => 'USD', // Base currency used in system unless specified otherwise, but let's log the actual amount
                'payment_method' => 'stripe'
            ]);

            Response::json($response);
            return;
        }
        $gatewayErrorCode = (string)($response['error_code'] ?? 'STRIPE_INIT_ERROR');
        $gatewayHttpCode = (int)($response['http_code'] ?? 0);
        $httpStatus = $gatewayErrorCode === 'STRIPE_CONFIG_MISSING' ? 503 : 502;
        Response::fail(
            $httpStatus,
            $response['message'] ?? 'Failed to initialize Stripe payment',
            'PAYMENT_PROVIDER_INIT_FAILED',
            [
                'provider' => 'stripe',
                'gateway_error_code' => $gatewayErrorCode,
                'gateway_http_code' => $gatewayHttpCode > 0 ? $gatewayHttpCode : null
            ]
        );
    }

    public function stripeWebhook(): void
    {
        $rawInput = file_get_contents('php://input');
        $signature = $_SERVER['HTTP_STRIPE_SIGNATURE'] ?? '';
        $secret = env('STRIPE_WEBHOOK_SECRET', '');

        if (!empty($secret)) {
            if (empty($signature)) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'Missing Stripe-Signature header']);
                exit();
            }

            if (!$this->verifyStripeSignature($rawInput, $signature, $secret)) {
                http_response_code(401);
                echo json_encode(['status' => 'error', 'message' => 'Invalid Stripe signature']);
                exit();
            }
        } else {
            error_log('Stripe webhook received without STRIPE_WEBHOOK_SECRET configured');
        }

        $event = json_decode($rawInput, true);
        if (!$event) {
            http_response_code(400);
            exit();
        }

        $eventId = (string)($event['id'] ?? '');
        if ($eventId !== '' && Cache::get('stripe_webhook_event:' . $eventId) === true) {
            http_response_code(200);
            echo json_encode(['status' => 'success', 'duplicate' => true]);
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

        if ($eventId !== '') {
            Cache::set('stripe_webhook_event:' . $eventId, true, 7 * 24 * 60 * 60);
        }

        http_response_code(200);
        echo json_encode(['status' => 'success']);
    }

    private function verifyStripeSignature(string $payload, string $sigHeader, string $secret): bool
    {
        $parts = explode(',', $sigHeader);
        $timestamp = null;
        $signatures = [];

        foreach ($parts as $p) {
            $kv = explode('=', trim($p), 2);
            if (count($kv) !== 2) {
                continue;
            }
            [$k, $v] = $kv;
            if ($k === 't') {
                $timestamp = $v;
            }
            if ($k === 'v1') {
                $signatures[] = $v;
            }
        }

        if (empty($timestamp) || empty($signatures)) {
            return false;
        }

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
            if (hash_equals($expected, $sig)) {
                return true;
            }
        }
        return false;
    }
}
