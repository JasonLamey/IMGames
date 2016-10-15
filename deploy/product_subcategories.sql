-- Deploy imgames:product_subcategories to mysql
-- requires: appuser
-- requires: product_categories

BEGIN;

CREATE TABLE IF NOT EXISTS product_subcategories
(
  id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  subcategory VARCHAR(255) NOT NULL,
  category_id BIGINT(20) UNSIGNED NOT NULL,
  created_on DATETIME NOT NULL DEFAULT NOW(),
  updated_on TIMESTAMP,

  PRIMARY KEY ( id ),
  CONSTRAINT FOREIGN KEY ( category_id )
    REFERENCES product_categories ( id )
);

COMMIT;
