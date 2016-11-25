-- Revert imgames:product_notify from mysql

BEGIN;

DROP TABLE product_notify;

COMMIT;
