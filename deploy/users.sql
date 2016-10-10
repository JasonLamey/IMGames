-- Deploy imgames:users to mysql
-- requires: appuser
-- requires: roles

BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id            BIGINT(20)  UNSIGNED NOT NULL AUTO_INCREMENT,
  username      VARCHAR(30)          NOT NULL,
  first_name    VARCHAR(255)                  DEFAULT NULL,
  last_name     VARCHAR(255)                  DEFAULT NULL,
  password      CHAR(73)             NOT NULL,
  birthdate     DATE                 NOT NULL,
  email         VARCHAR(255)         NOT NULL,
  confirmed     TINYINT(1)  UNSIGNED NOT NULL DEFAULT 0,
  lastlogin     DATETIME                      DEFAULT NULL,
  pw_changed    DATETIME                      DEFAULT NULL,
  pw_reset_code VARCHAR(255)                  DEFAULT NULL,
  created_on    DATETIME             NOT NULL DEFAULT NOW(),
  updated_on    TIMESTAMP                     DEFAULT NULL,

  PRIMARY KEY ( id )
);

COMMIT;
