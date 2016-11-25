-- Verify imgames:product_notify on mysql

BEGIN;

SELECT id, product_id FROM product_notify
  WHERE 0;

ROLLBACK;
