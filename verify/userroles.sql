-- Verify imgames:userroles on mysql

BEGIN;

SELECT user_id, role_id
  FROM user_roles
  WHERE 0;

ROLLBACK;
