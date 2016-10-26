-- Verify imgames:product_reviews on mysql

BEGIN;

SELECT id, title FROM product_reviews
  WHERE 0;

ROLLBACK;
