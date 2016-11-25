-- Deploy imgames:product_notify to mysql
-- requires: appuser
-- requires: products

BEGIN;

CREATE TABLE IF NOT EXISTS product_notify
(
  id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id BIGINT(20) UNSIGNED NOT NULL,
  email VARCHAR(255) NOT NULL,
  created_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY( id ),
  CONSTRAINT FOREIGN KEY( product_id )
    REFERENCES products( id )
);

COMMIT;
