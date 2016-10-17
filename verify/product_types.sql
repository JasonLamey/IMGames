-- Verify imgames:product_types on mysql

BEGIN;

SELECT id, type FROM product_types
  WHERE 0;

ROLLBACK;
