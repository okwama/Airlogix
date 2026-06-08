-- ==============================================================================
-- Airlogix Database Modification Script
-- Purpose: Enforce idempotency on payment gateway webhooks.
-- Author: Antigravity AI
-- Instructions for DB Team: 
-- Please run this ALTER TABLE command on the live database.
-- If it fails due to existing duplicate records, you may need to deduplicate
-- the payment_transactions table first by removing duplicate transaction_ids
-- for the same payment_method.
-- ==============================================================================

ALTER TABLE `payment_transactions`
ADD UNIQUE KEY `uq_payment_method_transaction` (`payment_method`, `transaction_id`);
