-- Deploy imgames:acl to mysql
-- requires: appuser

BEGIN;

CREATE TABLE IF NOT EXISTS roles (
  id         BIGINT(20)  UNSIGNED NOT NULL AUTO_INCREMENT,
  role       VARCHAR(30)          NOT NULL,
  created_on DATETIME             NOT NULL DEFAULT NOW(),
  updated_on TIMESTAMP                     DEFAULT NULL,

  PRIMARY KEY ( id )
);

COMMIT;
