-- Verify imgames:product_subcategories on mysql

BEGIN;

SELECT id, subcategory FROM product_subcategories
  WHERE 0;

ROLLBACK;
