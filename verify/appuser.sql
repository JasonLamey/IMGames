-- Verify imgames:appuser on mysql

BEGIN;

SELECT sqitch.checkit(COUNT(*), 'User "dbmonkey" does not exist')
  FROM mysql.user WHERE user = 'dbmonkey';

ROLLBACK;
