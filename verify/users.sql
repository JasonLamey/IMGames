-- Verify imgames:users on mysql

BEGIN;

SELECT id, username, first_name, last_name, password, birthdate, email, acl_id, confirmed, created_on, updated_on
  FROM users WHERE 0;

ROLLBACK;
