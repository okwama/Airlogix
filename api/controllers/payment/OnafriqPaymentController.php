<?php

require_once __DIR__ . '/PaymentControllerBase.php';

final class OnafriqPaymentController extends PaymentControllerBase
{
    public function initializeOnafriq(): void
    {
        $data = request_json();

        if (empty($data['phone_number']) || empty($data['booking_reference'])) {
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

        require_once dirname(__DIR__, 2) . '/services/OnafriqService.php';
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
            Response::fail(
                502,
                $response['message'] ?? 'Failed to initialize payment',
                'PAYMENT_PROVIDER_INIT_FAILED',
                ['provider' => 'onafriq']
            );
        }
    }

    public function onafriqCallback(): void
    {
        $callbackData = request_json();

        require_once dirname(__DIR__, 2) . '/services/OnafriqService.php';
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
        } else {
            $paymentData = $result['data'] ?? [];
            $bookingReference = $paymentData['booking_reference'] ?? null;
            if ($bookingReference) {
                $booking = $this->bookingModel->getByReference($bookingReference);
                if ($booking) {
                    $this->bookingModel->updatePaymentStatus(
                        $booking['id'],
                        'failed',
                        'onafriq'
                    );
                    $this->notifyPaymentFailed(
                        $booking,
                        'onafriq',
                        (string)($result['message'] ?? $paymentData['message'] ?? '')
                    );
                    Observability::event('payment.failed', [
                        'booking_id' => (int)$booking['id'],
                        'booking_reference' => (string)($booking['booking_reference'] ?? ''),
                        'method' => 'onafriq',
                        'gateway_reference' => (string)($paymentData['transaction_id'] ?? ''),
                        'gateway_status' => (string)($result['payment_status'] ?? 'failed'),
                        'gateway_message' => (string)($result['message'] ?? $paymentData['message'] ?? '')
                    ]);
                }
            }
        }

        Response::json($result);
    }

    public function onafriqStatus(): void
    {
        $transactionId = $_GET['transaction_id'] ?? '';

        if (empty($transactionId)) {
            Response::fail(400, 'Transaction ID is required', 'PAYMENT_REFERENCE_REQUIRED');
            return;
        }

        require_once dirname(__DIR__, 2) . '/services/OnafriqService.php';
        $db = db();
        $onafriq = new OnafriqService($db);

        $response = $onafriq->queryTransactionStatus($transactionId);
        Response::json($response);
    }
}
