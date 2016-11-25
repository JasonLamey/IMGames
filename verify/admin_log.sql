-- Verify imgames:admin_log on mysql

BEGIN;

SELECT log_level, log_message FROM admin_logs
  WHERE 0;

ROLLBACK;
