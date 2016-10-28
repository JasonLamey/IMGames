-- Deploy imgames:featured_products to mysql
-- requires: appuser
-- requires: products
-- requires: product_subcategories

BEGIN;

CREATE TABLE IF NOT EXISTS featured_products
(
  id                     BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id             BIGINT(20) UNSIGNED NOT NULL,
  product_subcategory_id BIGINT(20) UNSIGNED NOT NULL,
  expires_on DATE                                      DEFAULT NULL,
  created_on DATETIME                         NOT NULL DEFAULT NOW(),

  PRIMARY KEY( id ),
  CONSTRAINT FOREIGN KEY( product_id )
    REFERENCES products( id ),
  CONSTRAINT FOREIGN KEY( product_subcategory_id )
    REFERENCES product_subcategories( id )
);

COMMIT;
