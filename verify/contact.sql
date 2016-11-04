-- Verify imgames:contact on mysql

BEGIN;

SELECT id, name FROM contact_us
  WHERE 0;

ROLLBACK;
