-- Deploy imgames:product_categories to mysql
-- requires: appuser

BEGIN;

CREATE TABLE IF NOT EXISTS product_categories
(
  id         BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  category   VARCHAR(255) NOT NULL,
  shorthand  VARCHAR(255) NOT NULL,
  created_on DATETIME NOT NULL DEFAULT NOW(),
  updated_on TIMESTAMP NULL DEFAULT NULL,

  PRIMARY KEY(id)
);

COMMIT;
