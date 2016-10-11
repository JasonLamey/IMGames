-- Deploy imgames:populate_roles to mysql
-- requires: appuser
-- requires: roles

BEGIN;

INSERT INTO roles ( role, created_on )
VALUES
( 'Unconfirmed', NOW() ),
( 'Confirmed',   NOW() ),
( 'GameMaster',  NOW() ),
( 'Player',      NOW() ),
( 'Moderator',   NOW() ),
( 'Admin',       NOW() )
;

COMMIT;
