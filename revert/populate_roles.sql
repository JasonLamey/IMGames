-- Revert imgames:populate_roles from mysql

BEGIN;

DELETE FROM roles;

COMMIT;
