--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: account_registration_keys; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE account_registration_keys (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    token character varying,
    account_id character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: account_users; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE account_users (
    email citext NOT NULL,
    password_digest character varying NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    reset_password_token character varying,
    account_manager boolean DEFAULT false
);


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE accounts (
    subdomain character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    company_name character varying,
    default_locale character varying DEFAULT 'en'::character varying,
    timezone character varying,
    holiday_policy_id uuid,
    id uuid DEFAULT uuid_generate_v4() NOT NULL
);


--
-- Name: employee_attribute_definitions; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE employee_attribute_definitions (
    name character varying NOT NULL,
    label character varying,
    system boolean DEFAULT false NOT NULL,
    attribute_type character varying NOT NULL,
    validation hstore,
    account_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    multiple boolean DEFAULT false NOT NULL
);


--
-- Name: employee_attribute_versions; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE employee_attribute_versions (
    data hstore,
    employee_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    attribute_definition_id uuid,
    employee_event_id uuid,
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    "order" integer,
    multiple boolean DEFAULT false NOT NULL
);


--
-- Name: employee_events; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE employee_events (
    employee_id uuid,
    effective_at timestamp without time zone,
    comment text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    event_type character varying NOT NULL
);


--
-- Name: employee_attributes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW employee_attributes AS
 SELECT DISTINCT ON (employee_attribute_versions.employee_id, employee_attribute_versions.attribute_definition_id, employee_attribute_versions."order") employee_attribute_versions.id,
    employee_attribute_versions.data,
    employee_events.effective_at,
    employee_attribute_definitions.name AS attribute_name,
    employee_attribute_definitions.attribute_type,
    employee_attribute_versions.employee_id,
    employee_attribute_versions.id AS employee_attribute_version_id,
    employee_attribute_versions.employee_event_id,
    employee_attribute_versions.attribute_definition_id,
    employee_attribute_versions.created_at,
    employee_attribute_versions.updated_at,
    employee_attribute_versions."order"
   FROM ((employee_attribute_versions
     JOIN employee_events ON ((employee_attribute_versions.employee_event_id = employee_events.id)))
     JOIN employee_attribute_definitions ON ((employee_attribute_versions.attribute_definition_id = employee_attribute_definitions.id)))
  WHERE (employee_events.effective_at <= now())
  ORDER BY employee_attribute_versions.employee_id, employee_attribute_versions.attribute_definition_id, employee_attribute_versions."order", employee_events.effective_at DESC;


--
-- Name: employee_balances; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE employee_balances (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    balance integer DEFAULT 0,
    amount integer DEFAULT 0,
    time_off_id uuid,
    employee_id uuid NOT NULL,
    time_off_category_id uuid NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    being_processed boolean DEFAULT false,
    effective_at timestamp without time zone,
    validity_date timestamp without time zone,
    policy_credit_removal boolean DEFAULT false,
    policy_credit_addition boolean DEFAULT false,
    balance_credit_addition_id uuid
);


--
-- Name: employee_presence_policies; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE employee_presence_policies (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    presence_policy_id uuid NOT NULL,
    effective_at date NOT NULL,
    order_of_start_day integer DEFAULT 1 NOT NULL
);


--
-- Name: employee_time_off_policies; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE employee_time_off_policies (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    time_off_policy_id uuid NOT NULL,
    effective_at date NOT NULL,
    time_off_category_id uuid
);


--
-- Name: employee_working_places; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE employee_working_places (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    working_place_id uuid NOT NULL,
    effective_at date NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: employees; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE employees (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    account_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    account_user_id uuid
);


--
-- Name: holiday_policies; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE holiday_policies (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    name character varying NOT NULL,
    country character varying,
    region character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    account_id uuid
);


--
-- Name: holidays; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE holidays (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    name character varying NOT NULL,
    date date NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    holiday_policy_id uuid NOT NULL
);


--
-- Name: oauth_access_grants; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE oauth_access_grants (
    id integer NOT NULL,
    resource_owner_id uuid NOT NULL,
    application_id integer NOT NULL,
    token character varying NOT NULL,
    expires_in integer NOT NULL,
    redirect_uri text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    revoked_at timestamp without time zone,
    scopes character varying
);


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE oauth_access_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE oauth_access_grants_id_seq OWNED BY oauth_access_grants.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE oauth_access_tokens (
    id integer NOT NULL,
    resource_owner_id uuid,
    application_id integer,
    token character varying NOT NULL,
    refresh_token character varying,
    expires_in integer,
    revoked_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    scopes character varying
);


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE oauth_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE oauth_access_tokens_id_seq OWNED BY oauth_access_tokens.id;


--
-- Name: oauth_applications; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE oauth_applications (
    id integer NOT NULL,
    name character varying NOT NULL,
    uid character varying NOT NULL,
    secret character varying NOT NULL,
    redirect_uri text NOT NULL,
    scopes character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE oauth_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE oauth_applications_id_seq OWNED BY oauth_applications.id;


--
-- Name: presence_days; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE presence_days (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    "order" integer,
    presence_policy_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    minutes integer
);


--
-- Name: presence_policies; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE presence_policies (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    account_id uuid NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: time_entries; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE time_entries (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    start_time character varying NOT NULL,
    end_time character varying NOT NULL,
    presence_day_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    duration integer DEFAULT 0 NOT NULL
);


--
-- Name: time_off_categories; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE time_off_categories (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    name character varying NOT NULL,
    system boolean DEFAULT false NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: time_off_policies; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE time_off_policies (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    start_day integer NOT NULL,
    end_day integer,
    start_month integer NOT NULL,
    end_month integer,
    amount integer,
    years_to_effect integer,
    policy_type character varying NOT NULL,
    time_off_category_id uuid NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    years_passed integer DEFAULT 0 NOT NULL,
    name character varying NOT NULL
);


--
-- Name: time_offs; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE time_offs (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    end_time timestamp without time zone NOT NULL,
    start_time timestamp without time zone NOT NULL,
    time_off_category_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    being_processed boolean DEFAULT false
);


--
-- Name: working_place_time_off_policies; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE working_place_time_off_policies (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    working_place_id uuid NOT NULL,
    time_off_policy_id uuid NOT NULL,
    effective_at timestamp without time zone,
    time_off_category_id uuid
);


--
-- Name: working_places; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE working_places (
    name character varying NOT NULL,
    account_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    holiday_policy_id uuid
);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_access_grants ALTER COLUMN id SET DEFAULT nextval('oauth_access_grants_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_access_tokens ALTER COLUMN id SET DEFAULT nextval('oauth_access_tokens_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_applications ALTER COLUMN id SET DEFAULT nextval('oauth_applications_id_seq'::regclass);


--
-- Name: account_registration_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY account_registration_keys
    ADD CONSTRAINT account_registration_keys_pkey PRIMARY KEY (id);


--
-- Name: account_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY account_users
    ADD CONSTRAINT account_users_pkey PRIMARY KEY (id);


--
-- Name: accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: employee_attribute_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY employee_attribute_definitions
    ADD CONSTRAINT employee_attribute_definitions_pkey PRIMARY KEY (id);


--
-- Name: employee_attribute_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY employee_attribute_versions
    ADD CONSTRAINT employee_attribute_versions_pkey PRIMARY KEY (id);


--
-- Name: employee_balances_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY employee_balances
    ADD CONSTRAINT employee_balances_pkey PRIMARY KEY (id);


--
-- Name: employee_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY employee_events
    ADD CONSTRAINT employee_events_pkey PRIMARY KEY (id);


--
-- Name: employee_presence_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY employee_presence_policies
    ADD CONSTRAINT employee_presence_policies_pkey PRIMARY KEY (id);


--
-- Name: employee_time_off_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY employee_time_off_policies
    ADD CONSTRAINT employee_time_off_policies_pkey PRIMARY KEY (id);


--
-- Name: employee_working_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY employee_working_places
    ADD CONSTRAINT employee_working_places_pkey PRIMARY KEY (id);


--
-- Name: employees_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: holiday_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY holiday_policies
    ADD CONSTRAINT holiday_policies_pkey PRIMARY KEY (id);


--
-- Name: holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY holidays
    ADD CONSTRAINT holidays_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY oauth_access_grants
    ADD CONSTRAINT oauth_access_grants_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY oauth_access_tokens
    ADD CONSTRAINT oauth_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: oauth_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY oauth_applications
    ADD CONSTRAINT oauth_applications_pkey PRIMARY KEY (id);


--
-- Name: presence_days_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY presence_days
    ADD CONSTRAINT presence_days_pkey PRIMARY KEY (id);


--
-- Name: presence_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY presence_policies
    ADD CONSTRAINT presence_policies_pkey PRIMARY KEY (id);


--
-- Name: time_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY time_entries
    ADD CONSTRAINT time_entries_pkey PRIMARY KEY (id);


--
-- Name: time_off_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY time_off_categories
    ADD CONSTRAINT time_off_categories_pkey PRIMARY KEY (id);


--
-- Name: time_off_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY time_off_policies
    ADD CONSTRAINT time_off_policies_pkey PRIMARY KEY (id);


--
-- Name: time_offs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY time_offs
    ADD CONSTRAINT time_offs_pkey PRIMARY KEY (id);


--
-- Name: working_place_time_off_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY working_place_time_off_policies
    ADD CONSTRAINT working_place_time_off_policies_pkey PRIMARY KEY (id);


--
-- Name: working_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY working_places
    ADD CONSTRAINT working_places_pkey PRIMARY KEY (id);


--
-- Name: employee_attribute_versions_uniqueness_partial; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX employee_attribute_versions_uniqueness_partial ON employee_attribute_versions USING btree (attribute_definition_id, employee_id, employee_event_id) WHERE (multiple = false);


--
-- Name: index_account_registration_keys_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_account_registration_keys_on_account_id ON account_registration_keys USING btree (account_id);


--
-- Name: index_account_users_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_account_users_on_account_id ON account_users USING btree (account_id);


--
-- Name: index_account_users_on_email_and_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_account_users_on_email_and_account_id ON account_users USING btree (email, account_id);


--
-- Name: index_accounts_on_subdomain; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_accounts_on_subdomain ON accounts USING btree (subdomain);


--
-- Name: index_employee_attribute_definitions_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_attribute_definitions_on_account_id ON employee_attribute_definitions USING btree (account_id);


--
-- Name: index_employee_attribute_definitions_on_name_and_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_employee_attribute_definitions_on_name_and_account_id ON employee_attribute_definitions USING btree (name, account_id);


--
-- Name: index_employee_attribute_versions_on_attribute_definition_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_attribute_versions_on_attribute_definition_id ON employee_attribute_versions USING btree (attribute_definition_id);


--
-- Name: index_employee_attribute_versions_on_employee_event_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_attribute_versions_on_employee_event_id ON employee_attribute_versions USING btree (employee_event_id);


--
-- Name: index_employee_attribute_versions_on_employee_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_attribute_versions_on_employee_id ON employee_attribute_versions USING btree (employee_id);


--
-- Name: index_employee_balances_on_balance_credit_addition_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_balances_on_balance_credit_addition_id ON employee_balances USING btree (balance_credit_addition_id);


--
-- Name: index_employee_balances_on_employee_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_balances_on_employee_id ON employee_balances USING btree (employee_id);


--
-- Name: index_employee_balances_on_time_off_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_balances_on_time_off_category_id ON employee_balances USING btree (time_off_category_id);


--
-- Name: index_employee_balances_on_time_off_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_balances_on_time_off_id ON employee_balances USING btree (time_off_id);


--
-- Name: index_employee_events_on_employee_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_events_on_employee_id ON employee_events USING btree (employee_id);


--
-- Name: index_employee_id_presence_policy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_id_presence_policy_id ON employee_presence_policies USING btree (presence_policy_id, employee_id);


--
-- Name: index_employee_id_time_off_policy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_id_time_off_policy_id ON employee_time_off_policies USING btree (time_off_policy_id, employee_id);


--
-- Name: index_employee_presence_policies_on_employee_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_presence_policies_on_employee_id ON employee_presence_policies USING btree (employee_id);


--
-- Name: index_employee_presence_policies_on_presence_policy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_presence_policies_on_presence_policy_id ON employee_presence_policies USING btree (presence_policy_id);


--
-- Name: index_employee_presence_policy_effective_at; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_employee_presence_policy_effective_at ON employee_presence_policies USING btree (employee_id, presence_policy_id, effective_at);

--
-- Name: index_employee_id_working_place_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_employee_id_working_place_id ON employee_working_places USING btree (working_place_id, employee_id, effective_at);


--
-- Name: index_employee_presence_policies_on_employee_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_presence_policies_on_employee_id ON employee_presence_policies USING btree (employee_id);


--
-- Name: index_employee_presence_policies_on_presence_policy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_presence_policies_on_presence_policy_id ON employee_presence_policies USING btree (presence_policy_id);


--
-- Name: index_employee_presence_policy_effective_at; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_employee_presence_policy_effective_at ON employee_presence_policies USING btree (employee_id, presence_policy_id, effective_at);


--
-- Name: index_employee_time_off_policies_on_employee_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_time_off_policies_on_employee_id ON employee_time_off_policies USING btree (employee_id);


--
-- Name: index_employee_time_off_policies_on_time_off_policy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employee_time_off_policies_on_time_off_policy_id ON employee_time_off_policies USING btree (time_off_policy_id);


--
-- Name: index_employee_time_off_policy_effective_at; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_employee_time_off_policy_effective_at ON employee_time_off_policies USING btree (employee_id, time_off_policy_id, effective_at);


--
-- Name: index_employees_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employees_on_account_id ON employees USING btree (account_id);


--
-- Name: index_employees_on_id_and_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_employees_on_id_and_account_id ON employees USING btree (id, account_id);


--
-- Name: index_employees_on_working_place_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_employees_on_working_place_id ON employees USING btree (working_place_id);


--
-- Name: index_holiday_policies_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_holiday_policies_on_account_id ON holiday_policies USING btree (account_id);


--
-- Name: index_holidays_on_holiday_policy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_holidays_on_holiday_policy_id ON holidays USING btree (holiday_policy_id);


--
-- Name: index_oauth_access_grants_on_token; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_oauth_access_grants_on_token ON oauth_access_grants USING btree (token);


--
-- Name: index_oauth_access_tokens_on_refresh_token; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_refresh_token ON oauth_access_tokens USING btree (refresh_token);


--
-- Name: index_oauth_access_tokens_on_resource_owner_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_oauth_access_tokens_on_resource_owner_id ON oauth_access_tokens USING btree (resource_owner_id);


--
-- Name: index_oauth_access_tokens_on_token; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_token ON oauth_access_tokens USING btree (token);


--
-- Name: index_oauth_applications_on_uid; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_oauth_applications_on_uid ON oauth_applications USING btree (uid);


--
-- Name: index_presence_days_on_presence_policy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_presence_days_on_presence_policy_id ON presence_days USING btree (presence_policy_id);


--
-- Name: index_presence_policies_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_presence_policies_on_account_id ON presence_policies USING btree (account_id);


--
-- Name: index_time_entries_on_presence_day_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_time_entries_on_presence_day_id ON time_entries USING btree (presence_day_id);


--
-- Name: index_time_off_categories_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_time_off_categories_on_account_id ON time_off_categories USING btree (account_id);


--
-- Name: index_time_off_policies_on_time_off_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_time_off_policies_on_time_off_category_id ON time_off_policies USING btree (time_off_category_id);


--
-- Name: index_time_offs_on_employee_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_time_offs_on_employee_id ON time_offs USING btree (employee_id);


--
-- Name: index_time_offs_on_time_off_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_time_offs_on_time_off_category_id ON time_offs USING btree (time_off_category_id);


--
-- Name: index_working_place_id_time_off_policy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_working_place_id_time_off_policy_id ON working_place_time_off_policies USING btree (time_off_policy_id, working_place_id);


--
-- Name: index_working_place_time_off_policies_on_time_off_policy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_working_place_time_off_policies_on_time_off_policy_id ON working_place_time_off_policies USING btree (time_off_policy_id);


--
-- Name: index_working_place_time_off_policies_on_working_place_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_working_place_time_off_policies_on_working_place_id ON working_place_time_off_policies USING btree (working_place_id);


--
-- Name: index_working_place_time_off_policy_effective_at; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_working_place_time_off_policy_effective_at ON working_place_time_off_policies USING btree (working_place_id, time_off_policy_id, effective_at);


--
-- Name: index_working_places_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_working_places_on_account_id ON working_places USING btree (account_id);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: fk_rails_06c847ea6d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_time_off_policies
    ADD CONSTRAINT fk_rails_06c847ea6d FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;


--
-- Name: fk_rails_09864faa3a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY working_place_time_off_policies
    ADD CONSTRAINT fk_rails_09864faa3a FOREIGN KEY (working_place_id) REFERENCES working_places(id) ON DELETE CASCADE;


--
-- Name: fk_rails_0c64f4ddd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY time_entries
    ADD CONSTRAINT fk_rails_0c64f4ddd5 FOREIGN KEY (presence_day_id) REFERENCES presence_days(id) ON DELETE CASCADE;


--
-- Name: fk_rails_1c5b30ec32; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY working_places
    ADD CONSTRAINT fk_rails_1c5b30ec32 FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


--
-- Name: fk_rails_1d20586b4f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_versions
    ADD CONSTRAINT fk_rails_1d20586b4f FOREIGN KEY (attribute_definition_id) REFERENCES employee_attribute_definitions(id);


--
-- Name: fk_rails_330c32d8d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_access_grants
    ADD CONSTRAINT fk_rails_330c32d8d9 FOREIGN KEY (resource_owner_id) REFERENCES account_users(id) ON DELETE CASCADE;


--
-- Name: fk_rails_489b112f2d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_balances
    ADD CONSTRAINT fk_rails_489b112f2d FOREIGN KEY (time_off_id) REFERENCES time_offs(id);


--
-- Name: fk_rails_4ce8347ccb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY time_off_categories
    ADD CONSTRAINT fk_rails_4ce8347ccb FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


--
-- Name: fk_rails_5092c7896c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY time_offs
    ADD CONSTRAINT fk_rails_5092c7896c FOREIGN KEY (time_off_category_id) REFERENCES time_off_categories(id);


--
-- Name: fk_rails_5a8fc35128; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_events
    ADD CONSTRAINT fk_rails_5a8fc35128 FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;


--
-- Name: fk_rails_6e495897f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_versions
    ADD CONSTRAINT fk_rails_6e495897f4 FOREIGN KEY (employee_event_id) REFERENCES employee_events(id) ON DELETE CASCADE;


--
-- Name: fk_rails_836004d785; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_definitions
    ADD CONSTRAINT fk_rails_836004d785 FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


--
-- Name: fk_rails_878bdb42b2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_balances
    ADD CONSTRAINT fk_rails_878bdb42b2 FOREIGN KEY (time_off_category_id) REFERENCES time_off_categories(id);


--
-- Name: fk_rails_8df7ccdc3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY holidays
    ADD CONSTRAINT fk_rails_8df7ccdc3f FOREIGN KEY (holiday_policy_id) REFERENCES holiday_policies(id) ON DELETE CASCADE;


--
-- Name: fk_rails_95b0b0db67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY presence_policies
    ADD CONSTRAINT fk_rails_95b0b0db67 FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


--
-- Name: fk_rails_aa3331fb5e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY working_place_time_off_policies
    ADD CONSTRAINT fk_rails_aa3331fb5e FOREIGN KEY (time_off_policy_id) REFERENCES time_off_policies(id) ON DELETE CASCADE;


--
-- Name: fk_rails_ae92552259; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY holiday_policies
    ADD CONSTRAINT fk_rails_ae92552259 FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


--
-- Name: fk_rails_b0c50133fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_balances
    ADD CONSTRAINT fk_rails_b0c50133fb FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;


--
-- Name: fk_rails_be9ada4c17; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_time_off_policies
    ADD CONSTRAINT fk_rails_be9ada4c17 FOREIGN KEY (time_off_policy_id) REFERENCES time_off_policies(id) ON DELETE CASCADE;


--
-- Name: fk_rails_c96445f213; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY account_users
    ADD CONSTRAINT fk_rails_c96445f213 FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


--
-- Name: fk_rails_d55a0137c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employees
    ADD CONSTRAINT fk_rails_d55a0137c3 FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


--
-- Name: fk_rails_d8df29117a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY time_off_policies
    ADD CONSTRAINT fk_rails_d8df29117a FOREIGN KEY (time_off_category_id) REFERENCES time_off_categories(id) ON DELETE CASCADE;


--
-- Name: fk_rails_e31d8e8b9d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY presence_days
    ADD CONSTRAINT fk_rails_e31d8e8b9d FOREIGN KEY (presence_policy_id) REFERENCES presence_policies(id) ON DELETE CASCADE;


--
-- Name: fk_rails_ee63f25419; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_access_tokens
    ADD CONSTRAINT fk_rails_ee63f25419 FOREIGN KEY (resource_owner_id) REFERENCES account_users(id) ON DELETE CASCADE;


--
-- Name: fk_rails_f5cbfdb8ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY time_offs
    ADD CONSTRAINT fk_rails_f5cbfdb8ce FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user",public;

INSERT INTO schema_migrations (version) VALUES ('20150506171210');

INSERT INTO schema_migrations (version) VALUES ('20150507081455');

INSERT INTO schema_migrations (version) VALUES ('20150508114830');

INSERT INTO schema_migrations (version) VALUES ('20150508131248');

INSERT INTO schema_migrations (version) VALUES ('20150512100209');

INSERT INTO schema_migrations (version) VALUES ('20150512130821');

INSERT INTO schema_migrations (version) VALUES ('20150610085334');

INSERT INTO schema_migrations (version) VALUES ('20150610114525');

INSERT INTO schema_migrations (version) VALUES ('20150611082337');

INSERT INTO schema_migrations (version) VALUES ('20150611083344');

INSERT INTO schema_migrations (version) VALUES ('20150622100614');

INSERT INTO schema_migrations (version) VALUES ('20150624093809');

INSERT INTO schema_migrations (version) VALUES ('20150701074146');

INSERT INTO schema_migrations (version) VALUES ('20150907081812');

INSERT INTO schema_migrations (version) VALUES ('20150907082834');

INSERT INTO schema_migrations (version) VALUES ('20150907123909');

INSERT INTO schema_migrations (version) VALUES ('20150908082010');

INSERT INTO schema_migrations (version) VALUES ('20150909143548');

INSERT INTO schema_migrations (version) VALUES ('20150916153548');

INSERT INTO schema_migrations (version) VALUES ('20150921123410');

INSERT INTO schema_migrations (version) VALUES ('20150921134559');

INSERT INTO schema_migrations (version) VALUES ('20150922083433');

INSERT INTO schema_migrations (version) VALUES ('20150922085326');

INSERT INTO schema_migrations (version) VALUES ('20150925101401');

INSERT INTO schema_migrations (version) VALUES ('20150925111512');

INSERT INTO schema_migrations (version) VALUES ('20150928085323');

INSERT INTO schema_migrations (version) VALUES ('20150928091924');

INSERT INTO schema_migrations (version) VALUES ('20150928121456');

INSERT INTO schema_migrations (version) VALUES ('20150928140803');

INSERT INTO schema_migrations (version) VALUES ('20150928144701');

INSERT INTO schema_migrations (version) VALUES ('20150928150447');

INSERT INTO schema_migrations (version) VALUES ('20150928151520');

INSERT INTO schema_migrations (version) VALUES ('20151023110907');

INSERT INTO schema_migrations (version) VALUES ('20151023112104');

INSERT INTO schema_migrations (version) VALUES ('20151023113241');

INSERT INTO schema_migrations (version) VALUES ('20151023122337');

INSERT INTO schema_migrations (version) VALUES ('20151026085745');

INSERT INTO schema_migrations (version) VALUES ('20151029090914');

INSERT INTO schema_migrations (version) VALUES ('20151101202320');

INSERT INTO schema_migrations (version) VALUES ('20151101202612');

INSERT INTO schema_migrations (version) VALUES ('20151101204258');

INSERT INTO schema_migrations (version) VALUES ('20151104121414');

INSERT INTO schema_migrations (version) VALUES ('20151106145302');

INSERT INTO schema_migrations (version) VALUES ('20151109122432');

INSERT INTO schema_migrations (version) VALUES ('20151109122557');

INSERT INTO schema_migrations (version) VALUES ('20151110141901');

INSERT INTO schema_migrations (version) VALUES ('20151110144636');

INSERT INTO schema_migrations (version) VALUES ('20151112084642');

INSERT INTO schema_migrations (version) VALUES ('20151112093944');

INSERT INTO schema_migrations (version) VALUES ('20151112101159');

INSERT INTO schema_migrations (version) VALUES ('20151117123029');

INSERT INTO schema_migrations (version) VALUES ('20151119150657');

INSERT INTO schema_migrations (version) VALUES ('20151130152501');

INSERT INTO schema_migrations (version) VALUES ('20151204091351');

INSERT INTO schema_migrations (version) VALUES ('20151209122309');

INSERT INTO schema_migrations (version) VALUES ('20151209162652');

INSERT INTO schema_migrations (version) VALUES ('20151214144417');

INSERT INTO schema_migrations (version) VALUES ('20151221114106');

INSERT INTO schema_migrations (version) VALUES ('20151221144158');

INSERT INTO schema_migrations (version) VALUES ('20151222101912');

INSERT INTO schema_migrations (version) VALUES ('20151222121052');

INSERT INTO schema_migrations (version) VALUES ('20160105092534');

INSERT INTO schema_migrations (version) VALUES ('20160108093551');

INSERT INTO schema_migrations (version) VALUES ('20160108110841');

INSERT INTO schema_migrations (version) VALUES ('20160108112741');

INSERT INTO schema_migrations (version) VALUES ('20160113111200');

INSERT INTO schema_migrations (version) VALUES ('20160113133430');

INSERT INTO schema_migrations (version) VALUES ('20160115120801');

INSERT INTO schema_migrations (version) VALUES ('20160119110649');

INSERT INTO schema_migrations (version) VALUES ('20160120143600');

INSERT INTO schema_migrations (version) VALUES ('20160122142845');

INSERT INTO schema_migrations (version) VALUES ('20160122152943');

INSERT INTO schema_migrations (version) VALUES ('20160125090608');

INSERT INTO schema_migrations (version) VALUES ('20160126142900');

INSERT INTO schema_migrations (version) VALUES ('20160126163922');

INSERT INTO schema_migrations (version) VALUES ('20160127110502');

INSERT INTO schema_migrations (version) VALUES ('20160127113247');

INSERT INTO schema_migrations (version) VALUES ('20160202112542');

INSERT INTO schema_migrations (version) VALUES ('20160203104303');

INSERT INTO schema_migrations (version) VALUES ('20160210170022');

INSERT INTO schema_migrations (version) VALUES ('20160216100000');

INSERT INTO schema_migrations (version) VALUES ('20160218120538');

INSERT INTO schema_migrations (version) VALUES ('20160219094523');

INSERT INTO schema_migrations (version) VALUES ('20160219112404');

INSERT INTO schema_migrations (version) VALUES ('20160309100705');

INSERT INTO schema_migrations (version) VALUES ('20160316092439');

INSERT INTO schema_migrations (version) VALUES ('20160324094939');

INSERT INTO schema_migrations (version) VALUES ('20160401084042');

INSERT INTO schema_migrations (version) VALUES ('20160401104731');

INSERT INTO schema_migrations (version) VALUES ('20160412122041');

INSERT INTO schema_migrations (version) VALUES ('20160418142554');

INSERT INTO schema_migrations (version) VALUES ('20160419101614');

INSERT INTO schema_migrations (version) VALUES ('20160419103050');

INSERT INTO schema_migrations (version) VALUES ('20160419142848');

INSERT INTO schema_migrations (version) VALUES ('20160502065212');

INSERT INTO schema_migrations (version) VALUES ('20160502104901');

INSERT INTO schema_migrations (version) VALUES ('20160502132953');

INSERT INTO schema_migrations (version) VALUES ('20160506084601');

INSERT INTO schema_migrations (version) VALUES ('20160506143400');

INSERT INTO schema_migrations (version) VALUES ('20160506135157');

INSERT INTO schema_migrations (version) VALUES ('20160510124516');

INSERT INTO schema_migrations (version) VALUES ('20160512142051');

INSERT INTO schema_migrations (version) VALUES ('20160515174339');
