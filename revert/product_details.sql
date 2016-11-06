-- Revert imgames:product_details from mysql

BEGIN;

ALTER TABLE products
  DROP COLUMN sku,
  DROP COLUMN views;

COMMIT;
