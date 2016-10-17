-- Deploy imgames:populate_prod_cats to mysql
-- requires: appuser
-- requires: product_categories

BEGIN;

INSERT INTO product_categories
(
  category, shorthand, created_on
)
VALUES
( 'Role Playing Games', 'rpgs',     NOW() ),
( 'Card Games',         'cards',    NOW() ),
( 'Upcoming Projects',  'upcoming', NOW() );

COMMIT;
