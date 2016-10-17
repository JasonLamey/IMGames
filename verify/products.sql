-- Verify imgames:products on mysql

BEGIN;

SELECT id, name FROM products
  WHERE 0;

ROLLBACK;
