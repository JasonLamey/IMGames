-- Deploy imgames:products to mysql
-- requires: appuser
-- requires: product_subcategories
-- requires: product_items

BEGIN;

CREATE TABLE IF NOT EXISTS products
(
  id                     BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  name                   VARCHAR(255)        NOT NULL,
  product_subcategory_id BIGINT(20) UNSIGNED NOT NULL,
  intro                  TEXT                NOT NULL,
  description            MEDIUMTEXT          NOT NULL,
  product_type_id        BIGINT(20) UNSIGNED NOT NULL,
  base_price             DECIMAL(7,2)        NOT NULL,
  created_on             DATETIME            NOT NULL DEFAULT NOW(),
  updated_on             TIMESTAMP               NULL DEFAULT NULL,

  PRIMARY KEY( id ),
  CONSTRAINT FOREIGN KEY( product_subcategory_id )
    REFERENCES product_subcategories( id ),
  CONSTRAINT FOREIGN KEY( product_type_id )
    REFERENCES product_types( id )
);

COMMIT;
