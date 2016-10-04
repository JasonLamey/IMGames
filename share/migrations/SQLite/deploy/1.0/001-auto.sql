-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Mon Oct  3 02:00:04 2016
-- 

;
BEGIN TRANSACTION;
--
-- Table: acl
--
CREATE TABLE acl (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(30) NOT NULL,
  access_level integer(5) NOT NULL,
  created_on DateTime NOT NULL DEFAULT '2016-10-03T06:00:03',
  updated_on Timestamp
);
--
-- Table: users
--
CREATE TABLE users (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(30) NOT NULL,
  first_name varchar(255) NOT NULL,
  last_name varchar(255) NOT NULL,
  password char(73) NOT NULL,
  birthdate date NOT NULL,
  email varchar(255) NOT NULL,
  acl_id integer(2) NOT NULL DEFAULT 1,
  confirmed integer(1) NOT NULL DEFAULT 0,
  created_on DateTime NOT NULL DEFAULT '2016-10-03T06:00:03',
  updated_on Timestamp,
  FOREIGN KEY (acl_id) REFERENCES acl(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX users_idx_acl_id ON users (acl_id);
COMMIT;
