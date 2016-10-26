-- Deploy imgames:product_reviews to mysql
-- requires: appuser
-- requires: products
-- requires: users

BEGIN;

CREATE TABLE IF NOT EXISTS product_reviews
(
  id         BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id BIGINT(20) UNSIGNED NOT NULL,
  user_id    BIGINT(20) UNSIGNED NOT NULL,
  title      VARCHAR(255)        NOT NULL,
  content    TEXT                NOT NULL,
  rating     TINYINT(1) UNSIGNED NOT NULL,
  timestamp  DATETIME            NOT NULL DEFAULT NOW(),

  PRIMARY KEY( id ),
  CONSTRAINT FOREIGN KEY( product_id )
    REFERENCES products( id ),
  CONSTRAINT FOREIGN KEY( user_id )
    REFERENCES users( id )
);

COMMIT;
