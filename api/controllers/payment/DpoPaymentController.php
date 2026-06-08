<?php

require_once __DIR__ . '/PaymentControllerBase.php';

final class DpoPaymentController extends PaymentControllerBase
{
    public function initializeDPO(): void
    {
        $data = request_json();

        if (empty($data['booking_reference']) || empty($data['email'])) {
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

        require_once dirname(__DIR__, 2) . '/services/DPOService.php';
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
            Response::fail(
                502,
                $response['message'] ?? 'Failed to initialize payment',
                'PAYMENT_PROVIDER_INIT_FAILED',
                ['provider' => 'dpo']
            );
        }
    }

    public function dpoCallback(): void
    {
        $callbackData = $_GET;

        if (empty($callbackData)) {
            $input = file_get_contents('php://input');
            if (!empty($input)) {
                try {
                    $xml = simplexml_load_string($input);
                    $callbackData = json_decode(json_encode($xml), true);
                } catch (Exception $e) {
                    // Log error
                }
            }
        }

        require_once dirname(__DIR__, 2) . '/services/DPOService.php';
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
        } else {
            $paymentData = $result['data'] ?? [];
            $bookingReference = $paymentData['booking_reference'] ?? null;
            if ($bookingReference) {
                $booking = $this->bookingModel->getByReference($bookingReference);
                if ($booking) {
                    $this->bookingModel->updatePaymentStatus(
                        $booking['id'],
                        'failed',
                        'dpo'
                    );
                    $this->notifyPaymentFailed(
                        $booking,
                        'dpo',
                        (string)($result['message'] ?? $paymentData['message'] ?? '')
                    );
                    Observability::event('payment.failed', [
                        'booking_id' => (int)$booking['id'],
                        'booking_reference' => (string)($booking['booking_reference'] ?? ''),
                        'method' => 'dpo',
                        'gateway_reference' => (string)($paymentData['trans_token'] ?? ($callbackData['TransToken'] ?? $callbackData['trans_token'] ?? '')),
                        'gateway_status' => (string)($result['payment_status'] ?? 'failed'),
                        'gateway_message' => (string)($result['message'] ?? $paymentData['message'] ?? '')
                    ]);
                }
            }
        }

        if (isset($_GET['TransToken']) || isset($_GET['trans_token'])) {
            $status = $result['payment_status'] === 'success' ? 'success' : 'failed';
            $ref = $result['data']['booking_reference'] ?? '';
            header('Location: ' . env('APP_URL') . "/payment/result?status=$status&reference=$ref");
            exit();
        }

        echo 'OK';
        exit();
    }

    public function verifyDPO(): void
    {
        $transToken = $_GET['trans_token'] ?? '';

        if (empty($transToken)) {
            Response::fail(400, 'Transaction token is required', 'PAYMENT_REFERENCE_REQUIRED');
            return;
        }

        require_once dirname(__DIR__, 2) . '/services/DPOService.php';
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
            Response::fail(
                502,
                $response['message'] ?? 'Failed to verify payment',
                'PAYMENT_VERIFY_FAILED',
                ['provider' => 'dpo']
            );
        }
    }
}
