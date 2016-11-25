-- Revert imgames:product_controls from mysql

BEGIN;

ALTER TABLE products
  DROP COLUMN status,
  DROP COLUMN back_in_stock_date;

COMMIT;
