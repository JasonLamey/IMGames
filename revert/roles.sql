-- Revert imgames:acl from mysql

BEGIN;

DROP TABLE role;

COMMIT;
