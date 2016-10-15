-- Revert imgames:populate_prod_cats from mysql

BEGIN;

DELETE * FROM product_categories;

COMMIT;
