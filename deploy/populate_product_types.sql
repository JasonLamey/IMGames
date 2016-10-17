-- Deploy imgames:populate_product_types to mysql
-- requires: appuser
-- requires: product_types

BEGIN;

INSERT INTO product_types
(
  type, created_on
)
VALUES
( 'Core Rulebook', NOW() ),
( 'Source Book',   NOW() ),
( 'Basic Game',    NOW() ),
( 'Expansion',     NOW() );

COMMIT;
