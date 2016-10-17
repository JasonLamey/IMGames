-- Verify imgames:populate_product_types on mysql

BEGIN;

SELECT sqitch.checkit( COUNT(*), 'Product Type population did not work.' )
  FROM product_types
  WHERE type = 'Core Rulebook';

ROLLBACK;
