-- Verify imgames:product_categories on mysql

BEGIN;

SELECT id, category FROM product_categories
  WHERE 0;

ROLLBACK;
