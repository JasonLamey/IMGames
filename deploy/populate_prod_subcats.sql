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
( 'AfterLife',            3, NOW() ),
( 'Stick, To Your Guns!', 3, NOW() ),
( 'Death, Inc.',          3, NOW() );

COMMIT;
