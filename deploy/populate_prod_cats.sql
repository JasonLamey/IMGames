-- Deploy imgames:populate_prod_cats to mysql
-- requires: appuser
-- requires: product_categories

BEGIN;

INSERT INTO product_categories
(
  category, created_on
)
VALUES
( 'Role Playing Games', NOW() ),
( 'Card Games',         NOW() ),
( 'Upcoming Projects',  NOW() );

COMMIT;
