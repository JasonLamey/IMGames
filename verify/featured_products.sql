-- Verify imgames:featured_products on mysql

BEGIN;

SELECT id, product_id FROM featured_products
  WHERE 0;

ROLLBACK;
