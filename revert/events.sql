-- Revert imgames:events from mysql

BEGIN;

DROP TABLE events;

COMMIT;
