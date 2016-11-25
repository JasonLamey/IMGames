-- Deploy imgames:admin_log to mysql
-- requires: appuser

BEGIN;

CREATE TABLE IF NOT EXISTS admin_logs
(
  id          BIGINT(20)   UNSIGNED                       NOT NULL AUTO_INCREMENT,
  admin       VARCHAR(255)                                NOT NULL DEFAULT 'Unknown',
  ip_address  VARCHAR(255)                                NOT NULL DEFAULT 'Unknown',
  log_level   ENUM( 'Info', 'Warning', 'Error', 'Debug' ) NOT NULL DEFAULT 'Info',
  log_message TEXT                                        NOT NULL,
  created_on  DATETIME                                    NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY( id )
);

COMMIT;
