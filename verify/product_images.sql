-- Verify imgames:product_images on mysql

BEGIN;

SELECT id, product_id FROM product_images
  WHERE 0;

ROLLBACK;
