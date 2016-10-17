-- Revert imgames:populate_prod_subcats from mysql

BEGIN;

DELETE FROM product_subcategories;

COMMIT;
