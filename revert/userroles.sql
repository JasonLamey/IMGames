-- Revert imgames:userroles from mysql

BEGIN;

DROP TABLE user_roles;

COMMIT;
