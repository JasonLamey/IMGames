-- Revert imgames:acl from mysql

BEGIN;

DROP TABLE acl;

COMMIT;
