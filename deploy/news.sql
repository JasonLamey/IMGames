-- Deploy imgames:news to mysql
-- requires: appuser
-- requires: users

BEGIN;

CREATE TABLE IF NOT EXISTS news
(
  id         BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  title      VARCHAR(255)        NOT NULL,
  content    TEXT                NOT NULL,
  user_id    BIGINT(20) UNSIGNED NOT NULL,
  views      BIGINT(20) UNSIGNED NOT NULL DEFAULT 0,
  created_on DATETIME            NOT NULL DEFAULT NOW(),
  updated_on TIMESTAMP                    DEFAULT NULL,

  PRIMARY KEY( id ),
  CONSTRAINT FOREIGN KEY( user_id )
    REFERENCES users( id )
);

COMMIT;
