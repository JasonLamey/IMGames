-- Revert imgames:featured_products from mysql

BEGIN;

DROP TABLE featured_products;

COMMIT;
