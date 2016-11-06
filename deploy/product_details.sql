-- Deploy imgames:product_details to mysql
-- requires: appuser
-- requires: products

BEGIN;

ALTER TABLE products
  ADD COLUMN sku VARCHAR(15) DEFAULT NULL AFTER base_price,
  ADD COLUMN views INT UNSIGNED NOT NULL DEFAULT 0 AFTER sku;

COMMIT;
