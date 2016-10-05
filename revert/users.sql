-- Revert imgames:users from mysql

BEGIN;

DROP TABLE users;

COMMIT;
