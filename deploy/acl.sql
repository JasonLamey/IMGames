-- Deploy imgames:acl to mysql
-- requires: appuser

BEGIN;

CREATE TABLE IF NOT EXISTS acl (
  id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(30) NOT NULL,
  access_level INT(5) UNSIGNED NOT NULL,
  created_on DATETIME NOT NULL DEFAULT NOW(),
  updated_on TIMESTAMP NULL DEFAULT NULL
);

COMMIT;