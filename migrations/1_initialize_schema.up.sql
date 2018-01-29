-- hello world


CREATE TYPE PROJECT_TYPE_ENUM AS ENUM ('INTERNAL', 'PERSONAL', 'UPSA');

CREATE TYPE USER_ROLE_ENUM AS ENUM ('ADMINISTRATOR', 'USER');

CREATE TYPE USER_TYPE_ENUM AS ENUM ('INTERNAL', 'UPSA', 'GITHUB', 'LDAP');

CREATE TYPE PROJECT_ROLE_ENUM AS ENUM ('OPERATOR', 'CUSTOMER', 'MEMBER', 'PROJECT_MANAGER');

CREATE TYPE STATUS_ENUM AS ENUM ('IN_PROGRESS', 'PASSED', 'FAILED', 'STOPPED', 'SKIPPED', 'INTERRUPTED', 'RESETED', 'CANCELLED');

CREATE TYPE LAUNCH_MODE_ENUM AS ENUM ('DEFAULT', 'DEBUG');

CREATE TYPE BTS_TYPE_ENUM AS ENUM ('NONE', 'JIRA', 'TFS', 'RALLY');

CREATE TYPE AUTH_TYPE_ENUM AS ENUM ('OAUTH', 'NTLM', 'APIKEY', 'BASIC');

CREATE TYPE TEST_ITEM_TYPE_ENUM AS ENUM ('SUITE', 'STORY', 'TEST', 'SCENARIO', 'STEP', 'BEFORE_CLASS', 'BEFORE_GROUPS', 'BEFORE_METHOD',
  'BEFORE_SUITE', 'BEFORE_TEST', 'AFTER_CLASS', 'AFTER_GROUPS', 'AFTER_METHOD', 'AFTER_SUITE', 'AFTER_TEST');

-- CREATE TABLE defect_type (
--
-- )

CREATE TABLE bug_tracking_system (
  id   SERIAL CONSTRAINT bug_tracking_system_pk PRIMARY KEY,
  url  VARCHAR       NOT NULL,
  type BTS_TYPE_ENUM NOT NULL
  --   project ref?

);

CREATE TABLE defect_form_field (
  id                 SERIAL CONSTRAINT defect_form_field_pk PRIMARY KEY,
  bugtracking_system INTEGER REFERENCES bug_tracking_system (id) ON DELETE CASCADE,
  field_id           VARCHAR       NOT NULL,
  type               VARCHAR       NOT NULL,
  required           BOOLEAN       NOT NULL DEFAULT FALSE,
  values             VARCHAR ARRAY NOT NULL
);

CREATE TABLE defect_field_allowed_value (
  id                SERIAL CONSTRAINT defect_field_allowed_value_pk PRIMARY KEY,
  defect_form_field INTEGER REFERENCES defect_form_field (id) ON DELETE CASCADE,
  value_id          VARCHAR NOT NULL,
  value_name        VARCHAR NULL
);


CREATE TABLE project_email_configuration (
  id         SERIAL CONSTRAINT project_email_configuration_pk PRIMARY KEY,
  enabled    BOOLEAN DEFAULT FALSE NOT NULL,
  recipients VARCHAR ARRAY         NOT NULL
  --   email cases?
);

CREATE TABLE project_configuration (
  id                        SERIAL CONSTRAINT project_configuration_pk PRIMARY KEY,
  project_type              PROJECT_TYPE_ENUM          NOT NULL,
  interrupt_timeout         INTERVAL                   NOT NULL,
  keep_logs_interval        INTERVAL                   NOT NULL,
  keep_screenshots_interval INTERVAL                   NOT NULL,
  aa_enabled                BOOLEAN DEFAULT TRUE       NOT NULL,
  metadata                  JSONB                      NULL,
  email_configuration_id    INTEGER REFERENCES project_email_configuration (id) ON DELETE CASCADE UNIQUE,
  --   statistics sub type ???
  created_on                TIMESTAMP DEFAULT now()    NOT NULL
);


CREATE TABLE project (
  id                       SERIAL CONSTRAINT project_pk PRIMARY KEY,
  name                     VARCHAR                 NOT NULL,
  metadata                 JSONB                   NULL,
  created_on               TIMESTAMP DEFAULT now() NOT NULL,
  project_configuration_id INTEGER REFERENCES project_configuration (id) ON DELETE CASCADE UNIQUE
);


CREATE TABLE profile (
  id                 SERIAL CONSTRAINT profile_pk PRIMARY KEY,
  login              VARCHAR        NOT NULL UNIQUE,
  password           VARCHAR        NOT NULL,
  email              VARCHAR        NOT NULL,
  -- photos ?
  role               USER_ROLE_ENUM NOT NULL,
  type               USER_TYPE_ENUM NOT NULL,
  -- isExpired ?
  default_project_id INTEGER REFERENCES project (id) ON DELETE CASCADE,
  full_name          VARCHAR        NOT NULL,
  metadata           JSONB          NULL
);

CREATE TABLE profile_project (
  profile_id   INTEGER REFERENCES profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
  project_id   INTEGER REFERENCES project (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT profile_project_pk PRIMARY KEY (profile_id, project_id),
  project_role PROJECT_ROLE_ENUM NOT NULL
  -- proposed role ??
);

-- need to be recreated
CREATE TABLE activity (
  id            BIGSERIAL CONSTRAINT activity_pk PRIMARY KEY,
  profile_id    INTEGER REFERENCES profile (id) ON DELETE CASCADE,
  project_id    INTEGER REFERENCES project (id) ON DELETE CASCADE,
  last_modified TIMESTAMP DEFAULT now() NOT NULL,
  object_type   VARCHAR                 NOT NULL,
  action_type   VARCHAR                 NOT NULL,
  name          VARCHAR                 NOT NULL
  -- history ??
);

CREATE TABLE dashboard (
  id            SERIAL CONSTRAINT dashboard_pk PRIMARY KEY,
  name          VARCHAR                 NOT NULL,
  project_id    INTEGER REFERENCES project (id) ON DELETE CASCADE,
  creation_date TIMESTAMP DEFAULT now() NOT NULL,
  CONSTRAINT unq_name_project UNIQUE (name, project_id)
  -- acl ??
);

CREATE TABLE widget (
  id         SERIAL CONSTRAINT widget_id PRIMARY KEY,
  name       VARCHAR NOT NULL,
  -- content options ??
  -- applying filter id??
  project_id INTEGER REFERENCES project (id) ON DELETE CASCADE
  -- acl ???
);

CREATE TABLE dashboard_widget (
  dashboard_id      INTEGER REFERENCES dashboard (id) ON UPDATE CASCADE ON DELETE CASCADE,
  widget_id         INTEGER REFERENCES widget (id) ON UPDATE CASCADE ON DELETE CASCADE,
  widget_name       VARCHAR NOT NULL, -- make it as reference ??
  wdiget_width      INT     NOT NULL,
  widget_heigth     INT     NOT NULL,
  widget_position_x INT     NOT NULL,
  widget_position_y INT     NOT NULL,
  CONSTRAINT dashboard_widget_pk PRIMARY KEY (dashboard_id, widget_id),
  CONSTRAINT widget_on_dashboard_unq UNIQUE (dashboard_id, widget_name)
);

CREATE TABLE launch (
  id                   BIGSERIAL CONSTRAINT launch_pk PRIMARY KEY,
  project_id           INTEGER REFERENCES project (id) ON DELETE CASCADE ON UPDATE CASCADE             NOT NULL,
  profile_id           INTEGER REFERENCES profile (id) ON DELETE SET NULL ON UPDATE CASCADE,
  name                 VARCHAR(256)                                                                    NOT NULL,
  description          TEXT,
  start_time           TIMESTAMP                                                                       NOT NULL,
  end_time             TIMESTAMP,
  status               STATUS_ENUM                                                                     NOT NULL,
  -- tags as another table per project?
  -- statistics ???
  launch_number        BIGINT                                                                          NOT NULL,
  has_retries          BOOLEAN DEFAULT FALSE,
  last_modified        TIMESTAMP                                                                       NOT NULL,
  launch_mode          LAUNCH_MODE_ENUM                                                                NOT NULL,
  approximate_duration DOUBLE PRECISION,
  CONSTRAINT unq_name_number UNIQUE (name, launch_number)
);

CREATE TABLE test_item (
  id             BIGSERIAL CONSTRAINT test_item_pk PRIMARY KEY,
  name           VARCHAR(256),
  type           TEST_ITEM_TYPE_ENUM                                               NOT NULL,
  start_time     TIMESTAMP                                                         NOT NULL,
  end_time       TIMESTAMP,
  status         STATUS_ENUM                                                       NOT NULL,
  -- tags??
  -- statistics??
  -- path ??
  parent_item_id BIGINT REFERENCES test_item (id) ON DELETE CASCADE ON UPDATE CASCADE,
  retry_of       BIGINT REFERENCES test_item (id) ON DELETE CASCADE ON UPDATE CASCADE,
  launch_id      BIGINT REFERENCES launch (id) ON DELETE CASCADE ON UPDATE CASCADE NOT NULL,
  has_children   BOOLEAN DEFAULT FALSE,
  description    TEXT,
  last_modified  TIMESTAMP                                                         NOT NULL,
  unique_id      VARCHAR(256)                                                      NOT NULL
);

CREATE TABLE test_parameter (
  id           BIGSERIAL CONSTRAINT test_parameter_pk PRIMARY KEY,
  key          VARCHAR(256) NOT NULL,
  value        TEXT,
  test_item_id BIGINT REFERENCES test_item (id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE log (
  id            BIGSERIAL CONSTRAINT log_pk PRIMARY KEY,
  log_time      TIMESTAMP                                                            NOT NULL,
  log_message   TEXT                                                                 NOT NULL,
  -- binary content?
  test_item_id  BIGINT REFERENCES test_item (id) ON DELETE CASCADE ON UPDATE CASCADE NOT NULL,
  last_modified TIMESTAMP                                                            NOT NULL,
  log_level     INTEGER                                                              NOT NULL
)