-- Verify imgames:product_details on mysql

BEGIN;

SELECT sku, views FROM products
  WHERE 0;

ROLLBACK;
