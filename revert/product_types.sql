-- Revert imgames:product_types from mysql

BEGIN;

DROP TABLE product_types;

COMMIT;
