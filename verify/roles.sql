-- Verify imgames:roles on mysql

BEGIN;

SELECT id, role, created_on, updated_on
  FROM roles
  WHERE 0;

ROLLBACK;
