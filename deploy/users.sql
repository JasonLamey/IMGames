-- Deploy imgames:users to mysql
-- requires: appuser
-- requires: acl

BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(30) NOT NULL,
  first_name VARCHAR(255) NULL DEFAULT NULL,
  last_name VARCHAR(255) NULL DEFAULT NULL,
  password CHAR(73) NOT NULL,
  birthdate DATE NOT NULL,
  email VARCHAR(255) NOT NULL,
  acl_id BIGINT(20) UNSIGNED NOT NULL DEFAULT 1,
  confirmed INT(1) UNSIGNED NOT NULL DEFAULT 0,
  lastlogin DATETIME NULL DEFAULT NULL,
  pw_changed DATETIME NULL DEFAULT NULL,
  pw_reset_code VARCHAR(255) NULL DEFAULT NULL,
  created_on DATETIME NOT NULL DEFAULT NOW(),
  updated_on TIMESTAMP NULL DEFAULT NULL,
);

COMMIT;
