-- Verify imgames:userroles on mysql

BEGIN;

SELECT user_id, role_id, created_on, updated_on
  FROM user_roles
  WHERE 0;

ROLLBACK;
