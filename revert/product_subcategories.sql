-- Revert imgames:product_subcategories from mysql

BEGIN;

DROP TABLE product_subcategories;

COMMIT;
