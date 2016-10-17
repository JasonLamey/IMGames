-- Revert imgames:populate_product_types from mysql

BEGIN;

DELETE FROM product_types;

COMMIT;
