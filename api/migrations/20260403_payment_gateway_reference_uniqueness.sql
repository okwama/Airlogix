-- Harden payment callback replay safety at the database layer.
-- 1) Normalize blank transaction IDs to NULL.
-- 2) De-duplicate existing rows by (payment_method, transaction_id), keeping latest id.
-- 3) Add composite unique key for gateway references and a lookup index on transaction_id.

UPDATE payment_transactions
SET transaction_id = NULL
WHERE transaction_id IS NOT NULL
  AND TRIM(transaction_id) = '';

UPDATE payment_transactions t
JOIN payment_transactions newer
  ON t.payment_method = newer.payment_method
 AND t.transaction_id = newer.transaction_id
 AND t.id < newer.id
SET t.transaction_id = NULL
WHERE t.transaction_id IS NOT NULL
  AND t.transaction_id <> '';

SET @db_name = DATABASE();

SET @uniq_exists = (
  SELECT COUNT(1)
  FROM information_schema.statistics
  WHERE table_schema = @db_name
    AND table_name = 'payment_transactions'
    AND index_name = 'uniq_payment_gateway_method_ref'
);
SET @sql_uniq = IF(
  @uniq_exists = 0,
  'ALTER TABLE payment_transactions ADD UNIQUE KEY uniq_payment_gateway_method_ref (payment_method, transaction_id)',
  'SELECT 1'
);
PREPARE stmt_uniq FROM @sql_uniq;
EXECUTE stmt_uniq;
DEALLOCATE PREPARE stmt_uniq;

SET @txn_idx_exists = (
  SELECT COUNT(1)
  FROM information_schema.statistics
  WHERE table_schema = @db_name
    AND table_name = 'payment_transactions'
    AND index_name = 'idx_transaction_id'
);
SET @sql_txn_idx = IF(
  @txn_idx_exists = 0,
  'ALTER TABLE payment_transactions ADD KEY idx_transaction_id (transaction_id)',
  'SELECT 1'
);
PREPARE stmt_txn_idx FROM @sql_txn_idx;
EXECUTE stmt_txn_idx;
DEALLOCATE PREPARE stmt_txn_idx;

