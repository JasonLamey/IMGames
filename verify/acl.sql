-- Verify imgames:acl on mysql

BEGIN;

SELECT id, name, access_level, created_on, updated_on
  FROM acl
  WHERE 0;

ROLLBACK;
