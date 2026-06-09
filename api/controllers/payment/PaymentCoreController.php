<?php

require_once __DIR__ . '/PaymentControllerBase.php';

/**
 * Authenticated multi-gateway initiate (mobile app) and legacy/generic payment endpoints.
 */
final class PaymentCoreController extends PaymentControllerBase
{
    public function callback(): void
    {
        $data = request_json();

        if (empty($data['transaction_id']) || empty($data['status'])) {
            Response::fail(400, 'Missing transaction_id or status', 'PAYMENT_CALLBACK_INVALID');
            return;
        }

        $db = db();

        $stmt = $db->prepare('
            SELECT pt.*, b.booking_reference as booking_reference 
            FROM payment_transactions pt
            LEFT JOIN bookings b ON pt.booking_id = b.id
            WHERE pt.transaction_id = ? OR pt.payment_reference = ?
        ');
        $stmt->execute([$data['transaction_id'], $data['transaction_id']]);
        $transaction = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$transaction) {
            Response::fail(404, 'Transaction not found', 'PAYMENT_TRANSACTION_NOT_FOUND');
            return;
        }

        $newStatus = ($data['status'] === 'completed' || $data['status'] === 'success') ? 'completed' : 'failed';

        $updateStmt = $db->prepare('
            UPDATE payment_transactions 
            SET status = ?, payment_date = NOW(), metadata = ?
            WHERE id = ?
        ');
        $updateStmt->execute([$newStatus, json_encode($data), $transaction['id']]);

        if ($newStatus === 'completed') {
            $this->bookingModel->updatePaymentStatus(
                $transaction['booking_id'],
                'paid',
                $transaction['payment_method']
            );
            Observability::event('payment.success', [
                'booking_id' => (int)$transaction['booking_id'],
                'booking_reference' => (string)($transaction['booking_reference'] ?? ''),
                'method' => strtolower((string)($transaction['payment_method'] ?? 'legacy')),
                'gateway_reference' => (string)($data['transaction_id'] ?? ''),
                'source' => 'legacy_callback'
            ]);
        } else {
            $this->bookingModel->updatePaymentStatus(
                $transaction['booking_id'],
                'failed',
                $transaction['payment_method']
            );
            $booking = $this->bookingModel->getById((int)$transaction['booking_id']);
            if (is_array($booking)) {
                $this->notifyPaymentFailed(
                    $booking,
                    strtolower((string)($transaction['payment_method'] ?? 'legacy')),
                    (string)($data['message'] ?? '')
                );
            }
            Observability::event('payment.failed', [
                'booking_id' => (int)$transaction['booking_id'],
                'booking_reference' => (string)($transaction['booking_reference'] ?? ''),
                'method' => strtolower((string)($transaction['payment_method'] ?? 'legacy')),
                'gateway_reference' => (string)($data['transaction_id'] ?? ''),
                'source' => 'legacy_callback'
            ]);
        }

        Response::json([
            'status' => true,
            'message' => 'Payment status updated',
            'payment_status' => $newStatus
        ]);
    }

    public function initiate(): void
    {
        $user_id = $this->authenticate();
        $data = request_json();

        if (empty($data['booking_id']) || empty($data['amount']) || empty($data['payment_method'])) {
            Response::fail(400, 'Missing payment details: booking_id, amount, payment_method required', 'PAYMENT_INIT_MISSING_FIELDS');
            return;
        }

        $booking = $this->bookingModel->getById($data['booking_id']);

        if (!$booking) {
            Response::fail(404, 'Booking not found', 'BOOKING_NOT_FOUND');
            return;
        }

        if ($booking['user_id'] != $user_id) {
            Response::fail(403, 'Unauthorized: Booking does not belong to you', 'BOOKING_ACCESS_DENIED');
            return;
        }
        $this->ensureActiveReservation($booking);

        $requestedAmount = (float)$data['amount'];
        $expectedAmount = isset($booking['total_amount']) ? (float)$booking['total_amount'] : 0.0;
        $paymentStatus = $booking['payment_status'] ?? null;

        if ($paymentStatus === 'paid') {
            Response::fail(409, 'Booking is already marked as paid', 'BOOKING_ALREADY_PAID');
        }

        if ($expectedAmount <= 0) {
            error_log('Booking ' . $booking['id'] . ' has non-positive total_amount; blocking payment initiate');
            Response::fail(400, 'Booking has invalid total amount', 'BOOKING_AMOUNT_INVALID');
            return;
        }

        $requestedCurrency = $data['currency'] ?? 'USD';
        $normalizedExpected = $this->convertAmount($expectedAmount, 'USD', $requestedCurrency);

        $delta = abs($requestedAmount - $normalizedExpected);
        if ($delta > ($normalizedExpected * 0.05)) {
            error_log("Payment total mismatch: Requested $requestedAmount $requestedCurrency, expected $normalizedExpected $requestedCurrency (Original: $expectedAmount USD)");
            Response::fail(
                400,
                'Amount does not match booking total',
                'PAYMENT_AMOUNT_MISMATCH',
                [
                    'requested' => $requestedAmount,
                    'expected' => round($normalizedExpected, 2),
                    'currency' => $requestedCurrency
                ]
            );
            return;
        }

        $paymentMethod = strtolower($data['payment_method']);

        if ($paymentMethod === 'mpesa' || $paymentMethod === 'm-pesa') {
            if (empty($data['phone_number'])) {
                Response::fail(400, 'Phone number required for M-Pesa', 'PAYMENT_INIT_MISSING_FIELDS');
                return;
            }

            require_once dirname(__DIR__, 2) . '/services/MpesaService.php';
            $mpesa = new MpesaService(db());

            $response = $mpesa->initiateStkPush(
                $data['phone_number'],
                $data['amount'],
                $booking['booking_reference'],
                'Flight Booking - ' . $booking['booking_reference']
            );

            if ($response['status']) {
                $this->bookingModel->updatePaymentStatus(
                    $booking['id'],
                    'pending',
                    'mpesa'
                );

                $this->paymentModel->initiate([
                    'booking_id' => $booking['id'],
                    'user_id' => $booking['user_id'] ?? null,
                    'amount' => $data['amount'],
                    'currency' => 'KES', // Defaulting to KES for M-Pesa
                    'payment_method' => 'mpesa'
                ]);

                try {
                    $accessToken = $this->issueGuestAccessTokenForBooking($booking);
                } catch (Throwable $t) {
                    $accessToken = null;
                    error_log('Failed to issue guest access token for PaymentCore MPesa init: ' . $t->getMessage());
                }

                $out = [
                    'status' => true,
                    'message' => $response['message'],
                    'payment_method' => 'mpesa',
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
        } elseif ($paymentMethod === 'stripe') {
            if (empty($data['email'])) {
                Response::fail(400, 'Email required for Stripe payment', 'PAYMENT_INIT_MISSING_FIELDS');
                return;
            }

            require_once dirname(__DIR__, 2) . '/services/StripeService.php';
            $stripe = new StripeService();

            $clientChannel = strtolower(trim((string)($data['channel'] ?? 'web')));

            $response = $stripe->createCheckoutSession(
                $data['amount'],
                $data['currency'] ?? 'USD',
                $booking['booking_reference'],
                $data['email'],
                $clientChannel
            );

            if ($response['status']) {
                $this->bookingModel->updatePaymentStatus(
                    $booking['id'],
                    'pending',
                    'stripe'
                );

                $this->paymentModel->initiate([
                    'booking_id' => $booking['id'],
                    'user_id' => $booking['user_id'] ?? null,
                    'amount' => $data['amount'],
                    'currency' => $data['currency'] ?? 'USD',
                    'payment_method' => 'stripe'
                ]);

                try {
                    $accessToken = $this->issueGuestAccessTokenForBooking($booking);
                } catch (Throwable $t) {
                    $accessToken = null;
                    error_log('Failed to issue guest access token for PaymentCore Stripe init: ' . $t->getMessage());
                }

                $out = [
                    'status' => true,
                    'message' => 'Stripe Session created',
                    'payment_method' => 'stripe',
                    'data' => $response['data']
                ];
                if ($accessToken !== null) $out['access_token'] = $accessToken;
                Response::json($out);
            } else {
                Response::fail(
                    502,
                    $response['message'] ?? 'Failed to initialize Stripe payment',
                    'PAYMENT_PROVIDER_INIT_FAILED',
                    ['provider' => 'stripe']
                );
            }
        } else {
            Response::fail(400, 'Unsupported payment method: ' . $paymentMethod, 'PAYMENT_METHOD_UNSUPPORTED');
        }
    }
}
