-- Verify imgames:events on mysql

BEGIN;

SELECT id, name FROM events
  WHERE 0;

ROLLBACK;
