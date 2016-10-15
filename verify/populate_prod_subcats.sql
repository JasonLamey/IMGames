-- Verify imgames:populate_prod_subcats on mysql

BEGIN;

SELECT sqitch.checkit( COUNT(*), 'Populate Product Subcategories did not work' )
  FROM product_subcategories
  WHERE subcategory = 'Stellar Chaos';

ROLLBACK;
