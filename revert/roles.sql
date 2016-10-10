-- Revert imgames:acl from mysql

BEGIN;

DROP TABLE roles;

COMMIT;
