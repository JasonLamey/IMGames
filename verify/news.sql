-- Verify imgames:news on mysql

BEGIN;

SELECT id, title FROM news
  WHERE 0;

ROLLBACK;
