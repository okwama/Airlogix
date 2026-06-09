<?php

require_once __DIR__ . '/PaymentControllerBase.php';

final class PaystackPaymentController extends PaymentControllerBase
{
    public function initializePaystack(): void
    {
        $data = request_json();

        if (empty($data['email']) || empty($data['booking_reference'])) {
            Response::fail(400, 'Missing required payment details', 'PAYMENT_INIT_MISSING_FIELDS');
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

        $amount = (float)($booking['total_amount'] ?? 0);
        if ($amount <= 0) {
            Response::fail(400, 'Booking has invalid total amount', 'BOOKING_AMOUNT_INVALID');
            return;
        }

        require_once dirname(__DIR__, 2) . '/services/PaystackService.php';
        $paystack = new PaystackService();

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
            try {
                $accessToken = $this->issueGuestAccessTokenForBooking($booking);
            } catch (Throwable $t) {
                $accessToken = null;
                error_log('Failed to issue guest access token for Paystack init: ' . $t->getMessage());
            }

            $out = [
                'status' => true,
                'data' => $response['data'],
                'message' => 'Payment initialized successfully'
            ];
            if ($accessToken !== null) $out['access_token'] = $accessToken;
            Response::json($out);
        } else {
            Response::fail(
                502,
                $response['message'] ?? 'Failed to initialize payment',
                'PAYMENT_PROVIDER_INIT_FAILED',
                ['provider' => 'paystack']
            );
        }
    }

    public function verifyPaystack(): void
    {
        $reference = $_GET['reference'] ?? '';

        if (empty($reference)) {
            Response::fail(400, 'Payment reference is required', 'PAYMENT_REFERENCE_REQUIRED');
            return;
        }

        require_once dirname(__DIR__, 2) . '/services/PaystackService.php';
        $paystack = new PaystackService();

        $response = $paystack->verifyTransaction($reference);

        if ($response['status'] && isset($response['data'])) {
            $transactionData = $response['data'];

            if ($transactionData['status'] === 'success') {
                $bookingReference = $transactionData['metadata']['booking_reference'] ?? $reference;

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
                    Response::fail(404, 'Booking not found', 'BOOKING_NOT_FOUND');
                }
            } else {
                Response::fail(
                    409,
                    'Payment not successful',
                    'PAYMENT_NOT_SUCCESSFUL',
                    ['provider' => 'paystack', 'gateway_status' => $transactionData['status'] ?? null]
                );
            }
        } else {
            Response::fail(
                502,
                $response['message'] ?? 'Failed to verify payment',
                'PAYMENT_VERIFY_FAILED',
                ['provider' => 'paystack']
            );
        }
    }

    public function paystackWebhook(): void
    {
        $input = file_get_contents('php://input');
        $signature = $_SERVER['HTTP_X_PAYSTACK_SIGNATURE'] ?? '';

        if (!$signature) {
            http_response_code(400);
            exit();
        }

        $webhookSecret = env('PAYSTACK_SECRET_KEY');
        if ($signature !== hash_hmac('sha512', $input, $webhookSecret)) {
            http_response_code(401);
            exit();
        }

        $event = json_decode($input, true);

        if (($event['event'] ?? '') === 'charge.success') {
            $data = $event['data'];
            $reference = $data['reference'];
            $bookingReference = $data['metadata']['booking_reference'] ?? $reference;

            $booking = $this->bookingModel->getByReference($bookingReference);
            if ($booking) {
                $gatewayRef = (string)($data['reference'] ?? $reference);
                $this->finalizeSuccessfulPayment($booking, 'paystack', $gatewayRef, $data);
            }
        }

        http_response_code(200);
        echo json_encode(['status' => 'success']);
    }
}
