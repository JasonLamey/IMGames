-- Deploy imgames:appuser to mysql

BEGIN;

CREATE USER dbmonkey;

GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP
  ON imgames.* TO 'dbmonkey'@'localhost';

COMMIT;
