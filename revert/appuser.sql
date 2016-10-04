-- Revert imgames:appuser from mysql

BEGIN;

DROP USER dbmonkey;

COMMIT;
