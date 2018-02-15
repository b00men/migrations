-- hello world


CREATE TYPE PROJECT_TYPE_ENUM AS ENUM ('INTERNAL', 'PERSONAL', 'UPSA');

CREATE TYPE USER_ROLE_ENUM AS ENUM ('ADMINISTRATOR', 'USER');

CREATE TYPE USER_TYPE_ENUM AS ENUM ('INTERNAL', 'UPSA', 'GITHUB', 'LDAP');

CREATE TYPE PROJECT_ROLE_ENUM AS ENUM ('OPERATOR', 'CUSTOMER', 'MEMBER', 'PROJECT_MANAGER');

CREATE TYPE STATUS_ENUM AS ENUM ('IN_PROGRESS', 'PASSED', 'FAILED', 'STOPPED', 'SKIPPED', 'INTERRUPTED', 'RESETED', 'CANCELLED');

CREATE TYPE LAUNCH_MODE_ENUM AS ENUM ('DEFAULT', 'DEBUG');

CREATE TYPE BTS_TYPE_ENUM AS ENUM ('NONE', 'JIRA', 'TFS', 'RALLY');

CREATE TYPE AUTH_TYPE_ENUM AS ENUM ('OAUTH', 'NTLM', 'APIKEY', 'BASIC');

CREATE TYPE ACCESS_TOKEN_TYPE_ENUM AS ENUM ('OAUTH', 'NTLM', 'APIKEY', 'BASIC');

CREATE TYPE TEST_ITEM_TYPE_ENUM AS ENUM ('SUITE', 'STORY', 'TEST', 'SCENARIO', 'STEP', 'BEFORE_CLASS', 'BEFORE_GROUPS', 'BEFORE_METHOD',
  'BEFORE_SUITE', 'BEFORE_TEST', 'AFTER_CLASS', 'AFTER_GROUPS', 'AFTER_METHOD', 'AFTER_SUITE', 'AFTER_TEST');

CREATE TYPE ISSUE_GROUP_ENUM AS ENUM ('PRODUCT_BUG', 'AUTOMATION_BUG', 'SYSTEM_ISSUE', 'TO_INVESTIGATE', 'NO_DEFECT');

CREATE TABLE server_settings (
  id    SMALLSERIAL CONSTRAINT server_settings_id PRIMARY KEY,
  key   VARCHAR,
  value VARCHAR
);

------------------------------ Bug tracking systems ------------------------------
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
-----------------------------------------------------------------------------------


------------------------------ Project configurations ------------------------------
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

CREATE TABLE issue_type (
  id          SERIAL CONSTRAINT issue_type_pk PRIMARY KEY,
  issue_group ISSUE_GROUP_ENUM NOT NULL,
  locator     VARCHAR(64),
  long_name   VARCHAR(256),
  short_name  VARCHAR(64),
  hex_color   VARCHAR(7)
);

CREATE TABLE issue_type_project_configuration (
  configuration_id INTEGER REFERENCES project_configuration,
  issue_type_id    INTEGER REFERENCES issue_type,
  CONSTRAINT issue_type_project_configuration_pk PRIMARY KEY (configuration_id, issue_type_id)
);
-----------------------------------------------------------------------------------


---------------------------- Project and users ------------------------------------
CREATE TABLE project (
  id                       BIGSERIAL CONSTRAINT project_pk PRIMARY KEY,
  name                     VARCHAR NOT NULL,
  metadata                 JSONB   NULL,
  project_configuration_id INTEGER REFERENCES project_configuration (id) ON DELETE CASCADE UNIQUE
);

CREATE TABLE users (
  id                 SERIAL CONSTRAINT users_pk PRIMARY KEY,
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

CREATE TABLE project_user (
  user_id      INTEGER REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE,
  project_id   INTEGER REFERENCES project (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT users_project_pk PRIMARY KEY (user_id, project_id),
  project_role PROJECT_ROLE_ENUM NOT NULL
  -- proposed role ??
);

CREATE TABLE oauth_access_token (
  user_id    BIGINT REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE,
  token      VARCHAR                NOT NULL,
  token_type ACCESS_TOKEN_TYPE_ENUM NOT NULL,
  CONSTRAINT access_tokens_pk PRIMARY KEY (user_id, token_type)
);
-----------------------------------------------------------------------------------


-------------------------- Dashboards and widgets -----------------------------
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
-----------------------------------------------------------------------------------


--------------------------- Launches, items, logs --------------------------------------

CREATE TABLE launch (
  id            BIGSERIAL CONSTRAINT launch_pk PRIMARY KEY,
  project_id    INTEGER REFERENCES project (id) ON DELETE CASCADE ON UPDATE CASCADE NOT NULL,
  user_id       INTEGER REFERENCES users (id) ON DELETE SET NULL,
  name          VARCHAR(256)                                                        NOT NULL,
  description   TEXT,
  start_time    TIMESTAMP                                                           NOT NULL,
  number        INTEGER                                                             NOT NULL,
  last_modified TIMESTAMP DEFAULT now()                                             NOT NULL,
  mode          LAUNCH_MODE_ENUM                                                    NOT NULL,
  status        STATUS_ENUM                                                         NOT NULL,
  CONSTRAINT unq_name_number UNIQUE (name, number, project_id)
);

CREATE TABLE launch_tag (
  id        BIGSERIAL CONSTRAINT launch_tag_pk PRIMARY KEY,
  value     TEXT,
  launch_id BIGINT REFERENCES launch (id) ON DELETE CASCADE
);

CREATE TYPE PARAMETER AS (
  key   VARCHAR(256),
  value TEXT
);

CREATE TABLE test_item (
  id            BIGSERIAL CONSTRAINT test_item_pk PRIMARY KEY,
  name          VARCHAR(256),
  type          TEST_ITEM_TYPE_ENUM NOT NULL,
  start_time    TIMESTAMP           NOT NULL,
  description   TEXT,
  parameters    PARAMETER [],
  last_modified TIMESTAMP           NOT NULL,
  unique_id     VARCHAR(256)        NOT NULL
);

CREATE TABLE test_item_structure (
  id        BIGSERIAL CONSTRAINT test_item_structure_pk PRIMARY KEY,
  item_id   BIGINT REFERENCES test_item ON DELETE CASCADE UNIQUE,
  launch_id BIGINT REFERENCES launch ON DELETE CASCADE,
  parent_id BIGINT REFERENCES test_item_structure ON DELETE CASCADE,
  retry_of  BIGINT REFERENCES test_item_structure ON DELETE CASCADE
);

CREATE TABLE test_item_results (
  id       BIGSERIAL CONSTRAINT test_item_results_pk PRIMARY KEY,
  item_id  BIGINT REFERENCES test_item ON DELETE CASCADE UNIQUE,
  status   STATUS_ENUM NOT NULL,
  duration REAL
);

CREATE TABLE item_tag (
  id      SERIAL CONSTRAINT item_tag_pk PRIMARY KEY,
  value   TEXT,
  item_id BIGINT REFERENCES test_item (id) ON DELETE CASCADE
);


CREATE TABLE log (
  id            BIGSERIAL CONSTRAINT log_pk PRIMARY KEY,
  log_time      TIMESTAMP                                                            NOT NULL,
  log_message   TEXT                                                                 NOT NULL,
  item_id       BIGINT REFERENCES test_item (id) ON DELETE CASCADE ON UPDATE CASCADE NOT NULL,
  last_modified TIMESTAMP                                                            NOT NULL,
  log_level     INTEGER                                                              NOT NULL
);

----------------------------------------------------------------------------------------


------------------------------ Issue ticket many to many ------------------------------
CREATE TABLE issue (
  id                   BIGSERIAL CONSTRAINT issue_pk PRIMARY KEY,
  issue_type           INTEGER REFERENCES issue_type ON DELETE CASCADE,
  issue_description    TEXT,
  auto_analyzed        BOOLEAN DEFAULT FALSE,
  ignore_analyzer      BOOLEAN DEFAULT FALSE,
  test_item_results_id BIGINT REFERENCES test_item_results ON DELETE CASCADE UNIQUE
);

CREATE TABLE ticket (
  id           BIGSERIAL CONSTRAINT ticket_pk PRIMARY KEY,
  ticket_id    VARCHAR(64)                                                   NOT NULL UNIQUE,
  submitter_id INTEGER REFERENCES users (id)                                 NOT NULL,
  submit_date  TIMESTAMP DEFAULT now()                                       NOT NULL,
  bts_id       INTEGER REFERENCES bug_tracking_system (id) ON DELETE CASCADE NOT NULL,
  url          VARCHAR(256)                                                  NOT NULL
);

CREATE TABLE issue_ticket (
  issue_id  BIGINT REFERENCES issue (id),
  ticket_id BIGINT REFERENCES ticket (id),
  CONSTRAINT issue_ticket_pk PRIMARY KEY (issue_id, ticket_id)
);
----------------------------------------------------------------------------------------