-- Verify imgames:populate_roles on mysql

BEGIN;

SELECT * FROM roles
  WHERE role = 'Unconfirmed';

ROLLBACK;
