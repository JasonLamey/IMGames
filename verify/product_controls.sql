-- Verify imgames:product_controls on mysql

BEGIN;

SELECT status, back_in_stock_date FROM products
  WHERE 0;

ROLLBACK;
