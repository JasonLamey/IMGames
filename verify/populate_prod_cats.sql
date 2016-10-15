-- Verify imgames:populate_prod_cats on mysql

BEGIN;

SELECT sqitch.checkit( COUNT(*), 'Product Categories population did not work.' )
  FROM product_categories
  WHERE category = 'Role Playing Games';

ROLLBACK;
