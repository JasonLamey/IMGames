-- Deploy imgames:populate_prod_subcats to mysql
-- requires: appuser
-- requires: product_subcategories
-- requires: populate_prod_cats

BEGIN;

INSERT INTO product_subcategories
(
  subcategory, category_id, created_on
)
VALUES
( 'Stellar Chaos',        1, NOW() ),
( 'AfterLife',            2, NOW() ),
( 'Stick, To Your Guns!', 2, NOW() ),
( 'Death, Inc.',          2, NOW() );

COMMIT;
