-- Deploy imgames:appuser to mysql

BEGIN;

CREATE USER 'dbmonkey'@'localhost' IDENTIFIED BY '1DeeBeeMunkeez!';

GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP
  ON imgames.* TO 'dbmonkey'@'localhost';

COMMIT;
