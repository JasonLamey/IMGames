-- Verify imgames:user_logs on mysql

BEGIN;

SELECT * FROM user_logs
  WHERE 0;

ROLLBACK;
