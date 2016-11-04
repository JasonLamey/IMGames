-- Deploy imgames:contact to mysql
-- requires: appuser

BEGIN;

CREATE TABLE IF NOT EXISTS contact_us
(
  id         BIGINT(20)   UNSIGNED NOT NULL AUTO_INCREMENT,
  name       VARCHAR(255)          NOT NULL,
  email      VARCHAR(255)          NOT NULL,
  reason     VARCHAR(100)          NOT NULL,
  message    TEXT                  NOT NULL,
  created_on DATETIME              NOT NULL DEFAULT NOW(),

  PRIMARY KEY( id )
);

COMMIT;
