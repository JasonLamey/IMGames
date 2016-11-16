-- Deploy imgames:events to mysql
-- requires: appuser

BEGIN;

CREATE TABLE IF NOT EXISTS events
(
  id         BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  name       VARCHAR(255)        NOT NULL,
  start_date DATE                NOT NULL,
  end_date   DATE,
  start_time TIME                NOT NULL,
  end_time   TIME                NOT NULL,
  color      CHAR(7)                      DEFAULT NULL,
  url        VARCHAR(255)                 DEFAULT NULL,
  created_on DATETIME            NOT NULL,
  updated_on TIMESTAMP               NULL DEFAULT NULL,

  PRIMARY KEY( id )
);

COMMIT;
