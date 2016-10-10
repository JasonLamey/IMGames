-- Deploy imgames:userroles to mysql
-- requires: appuser
-- requires: roles
-- requires: users

BEGIN;

CREATE TABLE IF NOT EXISTS user_roles (
    user_id int(20) NOT NULL,
    role_id int(20) NOT NULL,
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (role_id) REFERENCES roles(id)
);

COMMIT;
