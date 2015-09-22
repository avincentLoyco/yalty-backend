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
    name character varying NOT NULL,
    label character varying,
    system boolean DEFAULT false NOT NULL,
    attribute_type character varying NOT NULL,
    validation hstore,
    account_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id uuid DEFAULT uuid_generate_v4() NOT NULL
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
    id uuid DEFAULT uuid_generate_v4() NOT NULL
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
 SELECT DISTINCT ON (employee_attribute_versions.employee_id, employee_attribute_versions.attribute_definition_id) employee_attribute_versions.id,
    employee_attribute_versions.data,
    employee_events.effective_at,
    employee_attribute_definitions.name AS attribute_name,
    employee_attribute_definitions.attribute_type,
    employee_attribute_versions.employee_id,
    employee_attribute_versions.id AS employee_attribute_version_id,
    employee_attribute_versions.employee_event_id,
    employee_attribute_versions.attribute_definition_id,
    employee_attribute_versions.created_at,
    employee_attribute_versions.updated_at
   FROM ((employee_attribute_versions
     JOIN employee_events ON ((employee_attribute_versions.employee_event_id = employee_events.id)))
     JOIN employee_attribute_definitions ON ((employee_attribute_versions.attribute_definition_id = employee_attribute_definitions.id)))
  WHERE (employee_events.effective_at <= now())
  ORDER BY employee_attribute_versions.employee_id, employee_attribute_versions.attribute_definition_id, employee_events.effective_at DESC;


--
-- Name: employees; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE employees (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    account_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    working_place_id uuid
);


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
-- Name: working_places; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE working_places (
    name character varying NOT NULL,
    account_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id uuid DEFAULT uuid_generate_v4() NOT NULL
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
-- Name: working_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY working_places
    ADD CONSTRAINT working_places_pkey PRIMARY KEY (id);


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
-- Name: index_employees_on_id_and_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_employees_on_id_and_account_id ON employees USING btree (id, account_id);


--
-- Name: index_employees_on_working_place_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_employees_on_working_place_id ON employees USING btree (working_place_id);


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
-- Name: index_working_places_on_account_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_working_places_on_account_id ON working_places USING btree (account_id);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: fk_rails_1c5b30ec32; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY working_places
    ADD CONSTRAINT fk_rails_1c5b30ec32 FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


--
-- Name: fk_rails_836004d785; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY employee_attribute_definitions
    ADD CONSTRAINT fk_rails_836004d785 FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE;


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

INSERT INTO schema_migrations (version) VALUES ('20150907123909');

INSERT INTO schema_migrations (version) VALUES ('20150908082010');

INSERT INTO schema_migrations (version) VALUES ('20150909143548');

INSERT INTO schema_migrations (version) VALUES ('20150916153548');

INSERT INTO schema_migrations (version) VALUES ('20150921123410');

INSERT INTO schema_migrations (version) VALUES ('20150921134559');

INSERT INTO schema_migrations (version) VALUES ('20150922085326');

