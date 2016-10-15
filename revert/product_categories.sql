-- Revert imgames:product_categories from mysql

BEGIN;

DROP TABLE product_categories;

COMMIT;
