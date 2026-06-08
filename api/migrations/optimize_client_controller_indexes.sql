-- Migration: Optimize indexes for ClientController queries
-- These indexes will improve query performance for client-related operations

-- 1. Composite index for ClientStock queries (getStock method)
-- This covers the WHERE clause: clientId, salesrepId, quantity > 0
-- Note: MySQL can use this index for range queries on quantity
ALTER TABLE `ClientStock` 
ADD INDEX `idx_clientstock_client_salesrep_qty` (`clientId`, `salesrepId`, `quantity`);

-- 2. Composite index for Clients list query (RELIEVER role)
-- Covers: status = 1 ORDER BY name
-- This is a covering index that can satisfy the query without accessing the table
ALTER TABLE `Clients`
ADD INDEX `idx_clients_status_name` (`status`, `name`);

-- 3. Verify existing indexes are optimal
-- The following indexes already exist and are being used:
-- - idx_clientassignment_salesrep_status_outlet (salesRepId, status, outletId) ✓
-- - idx_clientassignment_outlet_status (outletId, status, salesRepId) ✓
-- - idx_clientstock_client_product (clientId, productId) ✓
-- - idx_clientstock_salesrep (salesrepId) ✓
-- - idx_products_id_name (id, product_name) ✓

-- Performance Notes:
-- 1. list() method: 
--    - RELIEVER: Uses idx_clients_status_name (new) for covering index
--    - SALES_REP: Uses idx_clientassignment_salesrep_status_outlet (existing)
--
-- 2. get() method:
--    - RELIEVER: Uses primary key (id) - already optimal
--    - SALES_REP: Uses idx_clientassignment_outlet_status (existing)
--
-- 3. getStock() method:
--    - Uses idx_clientstock_client_salesrep_qty (new) for WHERE clause
--    - JOIN uses products primary key (id) - already optimal
--    - ORDER BY uses idx_products_id_name (existing)

