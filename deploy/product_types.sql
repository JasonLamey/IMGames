-- Deploy imgames:product_types to mysql
-- requires: appuser

BEGIN;

CREATE TABLE IF NOT EXISTS product_types
(
  id         BIGINT(20)   UNSIGNED NOT NULL AUTO_INCREMENT,
  type       VARCHAR(255)          NOT NULL,
  created_on DATETIME              NOT NULL DEFAULT NOW(),
  updated_on TIMESTAMP,

  PRIMARY KEY( id )
);

COMMIT;
