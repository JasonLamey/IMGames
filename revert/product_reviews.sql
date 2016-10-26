-- Revert imgames:product_reviews from mysql

BEGIN;

DROP TABLE product_reviews;

COMMIT;
