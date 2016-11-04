-- Revert imgames:contact from mysql

BEGIN;

DROP TABLE contact_us;

COMMIT;
