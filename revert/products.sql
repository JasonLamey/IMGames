-- Revert imgames:products from mysql

BEGIN;

DROP TABLE products;

COMMIT;
