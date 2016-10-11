-- Verify imgames:populate_roles on mysql

BEGIN;

SELECT sqitch.checkit( COUNT(*), 'User Roles population did not work.' )
  FROM roles
  WHERE role = 'Unconfirmed';

ROLLBACK;
