-- Revert imgames:appuser from mysql

BEGIN;

DROP USER 'dbmonkey'@'localhost';
FLUSH PRIVILEGES;

COMMIT;
