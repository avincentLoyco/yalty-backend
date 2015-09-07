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
-- Name: account_users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE account_users (
    id integer NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    account_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: account_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE account_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE account_users_id_seq OWNED BY account_users.id;


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE accounts (
    id integer NOT NULL,
    subdomain character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    company_name character varying
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE accounts_id_seq OWNED BY accounts.id;


--
-- Name: employee_attribute_definitions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE employee_attribute_definitions (
    id integer NOT NULL,
    name character varying NOT NULL,
    label character varying NOT NULL,
    system boolean DEFAULT false NOT NULL,
    attribute_type character varying NOT NULL,
    validation hstore,
    account_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: employee_attribute_definitions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE employee_attribute_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employee_attribute_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE employee_attribute_definitions_id_seq OWNED BY employee_attribute_definitions.id;


--
-- Name: employee_attribute_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE employee_attribute_versions (
    id integer NOT NULL,
    data hstore,
    employee_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    attribute_definition_id integer,
    employee_event_id integer
);


--
-- Name: employee_attribute_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE employee_attribute_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employee_attribute_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE employee_attribute_versions_id_seq OWNED BY employee_attribute_versions.id;


--
-- Name: employee_events; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE employee_events (
    id integer NOT NULL,
    employee_id integer,
    effective_at timestamp without time zone,
    comment text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: employee_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE employee_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employee_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE employee_events_id_seq OWNED BY employee_events.id;


--
-- Name: employees; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE employees (
    id integer NOT NULL,
    uuid uuid DEFAULT uuid_generate_v4(),
    account_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE employees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE employees_id_seq OWNED BY employees.id;


--
-- Name: oauth_access_grants; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE oauth_access_grants (
    id integer NOT NULL,
    resource_owner_id integer NOT NULL,
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
    resource_owner_id integer,
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY account_users ALTER COLUMN id SET DEFAULT nextval('account_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY accounts ALTER COLUMN id SET DEFAULT nextval('accounts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_definitions ALTER COLUMN id SET DEFAULT nextval('employee_attribute_definitions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_versions ALTER COLUMN id SET DEFAULT nextval('employee_attribute_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_events ALTER COLUMN id SET DEFAULT nextval('employee_events_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY employees ALTER COLUMN id SET DEFAULT nextval('employees_id_seq'::regclass);


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
-- Name: employee_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY employee_events
    ADD CONSTRAINT employee_events_pkey PRIMARY KEY (id);


--
-- Name: employees_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


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
-- Name: index_employee_events_on_employee_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_employee_events_on_employee_id ON employee_events USING btree (employee_id);


--
-- Name: index_employees_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_employees_on_account_id ON employees USING btree (account_id);


--
-- Name: index_employees_on_uuid_and_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_employees_on_uuid_and_account_id ON employees USING btree (uuid, account_id);


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
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: fk_rails_474a9d4b79; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_versions
    ADD CONSTRAINT fk_rails_474a9d4b79 FOREIGN KEY (attribute_definition_id) REFERENCES employee_attribute_definitions(id) ON DELETE CASCADE;


--
-- Name: fk_rails_5a8fc35128; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_events
    ADD CONSTRAINT fk_rails_5a8fc35128 FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;


--
-- Name: fk_rails_6e495897f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_versions
    ADD CONSTRAINT fk_rails_6e495897f4 FOREIGN KEY (employee_event_id) REFERENCES employee_events(id);


--
-- Name: fk_rails_836004d785; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_definitions
    ADD CONSTRAINT fk_rails_836004d785 FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


--
-- Name: fk_rails_c0f87401f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_versions
    ADD CONSTRAINT fk_rails_c0f87401f9 FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;


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

