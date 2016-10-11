-- Revert imgames:populate_roles from mysql

BEGIN;

TRUNCATE roles;

COMMIT;
