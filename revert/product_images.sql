-- Revert imgames:product_images from mysql

BEGIN;

DROP TABLE product_images;

COMMIT;
