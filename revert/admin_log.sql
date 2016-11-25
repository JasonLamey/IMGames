-- Revert imgames:admin_log from mysql

BEGIN;

DROP TABLE admin_logs;

COMMIT;
