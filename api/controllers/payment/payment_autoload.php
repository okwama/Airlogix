<?php
/**
 * Load payment controllers (base + per-gateway + core).
 * Included from index.php after config.php.
 */
require_once __DIR__ . '/PaymentControllerBase.php';
require_once __DIR__ . '/PaymentCoreController.php';
require_once __DIR__ . '/StripePaymentController.php';
require_once __DIR__ . '/PaystackPaymentController.php';
require_once __DIR__ . '/MpesaPaymentController.php';
require_once __DIR__ . '/OnafriqPaymentController.php';
require_once __DIR__ . '/DpoPaymentController.php';
