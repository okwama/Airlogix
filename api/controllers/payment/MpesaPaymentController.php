<?php

require_once __DIR__ . '/PaymentControllerBase.php';

final class MpesaPaymentController extends PaymentControllerBase
{
    public function initializeMpesa(): void
    {
        $data = request_json();

        if (empty($data['phone_number'])) {
            Response::fail(400, 'Phone number is required', 'PAYMENT_INIT_MISSING_FIELDS');
            return;
        }
        if (empty($data['booking_reference'])) {
            Response::fail(400, 'Booking reference is required', 'PAYMENT_INIT_MISSING_FIELDS');
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

        require_once dirname(__DIR__, 2) . '/services/MpesaService.php';
        $mpesa = new MpesaService(db());

        $response = $mpesa->initiateStkPush(
            $data['phone_number'],
            $amount,
            $booking['booking_reference'],
            $data['description'] ?? 'Flight Booking Payment'
        );

        if ($response['status']) {
            if ($booking) {
                $this->bookingModel->updatePaymentStatus(
                    $booking['id'],
                    'pending',
                    'mpesa'
                );

                $this->paymentModel->initiate([
                    'booking_id' => $booking['id'],
                    'user_id' => $booking['user_id'] ?? null,
                    'amount' => $amount,
                    'currency' => 'KES', // Defaulting to KES for M-Pesa
                    'payment_method' => 'mpesa'
                ]);
            }

            try {
                $accessToken = $this->issueGuestAccessTokenForBooking($booking);
            } catch (Throwable $t) {
                $accessToken = null;
                error_log('Failed to issue guest access token for Mpesa init: ' . $t->getMessage());
            }

            $out = [
                'status' => true,
                'message' => $response['message'],
                'data' => $response['data']
            ];
            if ($accessToken !== null) $out['access_token'] = $accessToken;
            Response::json($out);
        } else {
            Response::fail(
                502,
                $response['message'] ?? 'Failed to initialize M-Pesa payment',
                'PAYMENT_PROVIDER_INIT_FAILED',
                [
                    'provider' => 'mpesa',
                    'gateway_error_code' => $response['error_code'] ?? 'MPESA_ERROR'
                ]
            );
        }
    }

    public function mpesaCallback(): void
    {
        $rawInput = file_get_contents('php://input');
        $data = json_decode($rawInput, true);

        $logDir = dirname(__DIR__, 2) . '/logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        file_put_contents(
            $logDir . '/mpesa_callbacks_' . date('Y-m-d') . '.log',
            date('Y-m-d H:i:s') . ' CALLBACK: ' . $rawInput . PHP_EOL,
            FILE_APPEND
        );

        if (!$data || !isset($data['Body']['stkCallback'])) {
            http_response_code(400);
            echo json_encode(['ResultCode' => 1, 'ResultDesc' => 'Invalid callback data']);
            exit();
        }

        require_once dirname(__DIR__, 2) . '/services/MpesaService.php';
        $mpesa = new MpesaService(db());

        $result = $mpesa->processCallback($data);

        if ($result['status'] && $result['payment_status'] === 'success') {
            $paymentData = $result['data'];
            $bookingReference = $paymentData['booking_reference'];

            if ($bookingReference) {
                $booking = $this->bookingModel->getByReference($bookingReference);

                if ($booking) {
                    $gatewayRef = (string)($paymentData['checkout_request_id'] ?? $paymentData['merchant_request_id'] ?? '');
                    $this->finalizeSuccessfulPayment($booking, 'mpesa', $gatewayRef, $paymentData);
                }
            }

            http_response_code(200);
            echo json_encode(['ResultCode' => 0, 'ResultDesc' => 'Callback processed successfully']);
        } else {
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
                    $this->notifyPaymentFailed(
                        $booking,
                        'mpesa',
                        (string)($paymentData['result_desc'] ?? '')
                    );
                    Observability::event('payment.failed', [
                        'booking_id' => (int)$booking['id'],
                        'booking_reference' => (string)($booking['booking_reference'] ?? ''),
                        'method' => 'mpesa',
                        'gateway_reference' => (string)($paymentData['checkout_request_id'] ?? $paymentData['merchant_request_id'] ?? ''),
                        'gateway_status' => (string)($result['payment_status'] ?? 'failed'),
                        'gateway_message' => (string)($paymentData['result_desc'] ?? '')
                    ]);
                }
            }

            http_response_code(200);
            echo json_encode(['ResultCode' => 0, 'ResultDesc' => 'Callback received']);
        }
        exit();
    }

    public function queryMpesaStatus(): void
    {
        $checkoutRequestId = $_GET['checkout_request_id'] ?? '';

        if (empty($checkoutRequestId)) {
            Response::fail(400, 'checkout_request_id is required', 'PAYMENT_REFERENCE_REQUIRED');
            return;
        }

        require_once dirname(__DIR__, 2) . '/services/MpesaService.php';
        $mpesa = new MpesaService(db());

        $response = $mpesa->queryStkStatus($checkoutRequestId);

        Response::json($response);
    }
}
