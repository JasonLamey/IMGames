-- Deploy imgames:product_images to mysql
-- requires: appuser
-- requires: products

BEGIN;

CREATE TABLE IF NOT EXISTS product_images
(
  id         BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id BIGINT(20) UNSIGNED NOT NULL,
  filename   VARCHAR(255)        NOT NULL,
  highlight  BOOLEAN             NOT NULL DEFAULT 0,
  created_on DATETIME            NOT NULL DEFAULT NOW(),
  updated_on TIMESTAMP,

  PRIMARY KEY( id ),
  CONSTRAINT FOREIGN KEY( product_id )
    REFERENCES products( id )
);

COMMIT;
