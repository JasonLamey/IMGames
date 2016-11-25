-- Deploy imgames:product_controls to mysql
-- requires: appuser
-- requires: products

BEGIN;

ALTER TABLE products
  ADD COLUMN status ENUM( 'Unreleased', 'In Stock', 'Out of Stock', 'Discontinued' ) NOT NULL DEFAULT 'Unreleased' AFTER base_price,
  ADD COLUMN back_in_stock_date DATE NULL DEFAULT NULL AFTER status;

COMMIT;
