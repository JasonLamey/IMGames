-- Revert imgames:user_logs from mysql

BEGIN;

DROP TABLE user_logs;

COMMIT;
