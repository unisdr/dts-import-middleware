--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4

-- Started on 2025-07-16 14:24:42

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 289072)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 6254 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- TOC entry 766 (class 1255 OID 290152)
-- Name: dts_get_sector_ancestors_decentants(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dts_get_sector_ancestors_decentants(sector_id bigint) RETURNS json
    LANGUAGE sql
    AS $$
WITH RECURSIVE ParentCTE AS (
    -- Find all ancestors (parents)
    SELECT id, sectorname, parent_id, level
    FROM sector
    WHERE id = SECTOR_ID
    UNION ALL
    SELECT t.id, t.sectorname, t.parent_id, t.level
    FROM sector t
    INNER JOIN ParentCTE p ON t.id = p.parent_id
),
ChildCTE AS (
    -- Find all descendants (children)
    SELECT id, sectorname, parent_id, level
    FROM sector
    WHERE id = SECTOR_ID
    UNION ALL
    SELECT t.id, t.sectorname, t.parent_id, t.level
    FROM sector t
    INNER JOIN ChildCTE c ON t.parent_id = c.id
)
SELECT json_agg(row_to_json(all_records))
FROM (
    SELECT id, sectorname, level FROM ParentCTE WHERE level = 2
    UNION
    SELECT id, sectorname, level FROM ChildCTE
) all_records;
$$;


ALTER FUNCTION public.dts_get_sector_ancestors_decentants(sector_id bigint) OWNER TO postgres;

--
-- TOC entry 864 (class 1255 OID 290153)
-- Name: dts_get_sector_decendants(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dts_get_sector_decendants(sector_id bigint) RETURNS json
    LANGUAGE sql
    AS $$
WITH RECURSIVE ChildCTE AS (
    -- Find all descendants (children)
    SELECT id, sectorname, parent_id, level
    FROM sector
    WHERE id = SECTOR_ID
    UNION ALL
    SELECT t.id, t.sectorname, t.parent_id, t.level
    FROM sector t
    INNER JOIN ChildCTE c ON t.parent_id = c.id
)
SELECT json_agg(row_to_json(all_records))
FROM (
    SELECT id, sectorname, level FROM ChildCTE
) all_records;
$$;


ALTER FUNCTION public.dts_get_sector_decendants(sector_id bigint) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 221 (class 1259 OID 290154)
-- Name: __drizzle_migrations__; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.__drizzle_migrations__ (
    id integer NOT NULL,
    hash text NOT NULL,
    created_at bigint
);


ALTER TABLE public.__drizzle_migrations__ OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 290159)
-- Name: __drizzle_migrations___id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.__drizzle_migrations___id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.__drizzle_migrations___id_seq OWNER TO postgres;

--
-- TOC entry 6255 (class 0 OID 0)
-- Dependencies: 222
-- Name: __drizzle_migrations___id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.__drizzle_migrations___id_seq OWNED BY public.__drizzle_migrations__.id;


--
-- TOC entry 223 (class 1259 OID 290160)
-- Name: affected; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.affected (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dsg_id uuid NOT NULL,
    direct integer,
    indirect integer
);


ALTER TABLE public.affected OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 290164)
-- Name: api_key; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.api_key (
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    id bigint NOT NULL,
    secret text NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    user_id bigint NOT NULL
);


ALTER TABLE public.api_key OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 290172)
-- Name: api_key_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.api_key_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.api_key_id_seq OWNER TO postgres;

--
-- TOC entry 6256 (class 0 OID 0)
-- Dependencies: 225
-- Name: api_key_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.api_key_id_seq OWNED BY public.api_key.id;


--
-- TOC entry 226 (class 1259 OID 290173)
-- Name: asset; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.asset (
    api_import_id text,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sector_ids text NOT NULL,
    is_built_in boolean NOT NULL,
    name text NOT NULL,
    category text,
    national_id text,
    notes text
);


ALTER TABLE public.asset OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 290179)
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text NOT NULL,
    record_id text NOT NULL,
    user_id bigint NOT NULL,
    action text NOT NULL,
    old_values jsonb,
    new_values jsonb,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.audit_logs OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 290186)
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    name text NOT NULL,
    parent_id bigint,
    level bigint DEFAULT 1 NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.categories OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 290194)
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categories_id_seq OWNER TO postgres;

--
-- TOC entry 6257 (class 0 OID 0)
-- Dependencies: 229
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- TOC entry 230 (class 1259 OID 290195)
-- Name: country1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.country1 (
    id bigint NOT NULL,
    name jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE public.country1 OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 290201)
-- Name: country1_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.country1_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.country1_id_seq OWNER TO postgres;

--
-- TOC entry 6258 (class 0 OID 0)
-- Dependencies: 231
-- Name: country1_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.country1_id_seq OWNED BY public.country1.id;


--
-- TOC entry 232 (class 1259 OID 290202)
-- Name: damages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.damages (
    api_import_id text,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    record_id uuid NOT NULL,
    sector_id bigint NOT NULL,
    asset_id uuid NOT NULL,
    unit text,
    total_damage_amount bigint,
    total_damage_amount_override boolean DEFAULT false NOT NULL,
    total_repair_replacement numeric,
    total_repair_replacement_override boolean DEFAULT false NOT NULL,
    total_recovery numeric,
    total_recovery_override boolean DEFAULT false NOT NULL,
    pd_damage_amount bigint,
    pd_repair_cost_unit numeric,
    pd_repair_cost_unit_currency text,
    pd_repair_cost_total numeric,
    pd_repair_cost_total_override boolean DEFAULT false NOT NULL,
    pd_recovery_cost_unit numeric,
    pd_recovery_cost_unit_currency text,
    pd_recovery_cost_total numeric,
    pd_recovery_cost_total_override boolean DEFAULT false NOT NULL,
    pd_disruption_duration_days bigint,
    pd_disruption_duration_hours bigint,
    pd_disruption_users_affected bigint,
    pd_disruption_people_affected bigint,
    pd_disruption_description text,
    td_damage_amount bigint,
    td_replacement_cost_unit numeric,
    td_replacement_cost_unit_currency text,
    td_replacement_cost_total numeric,
    td_replacement_cost_total_override boolean DEFAULT false NOT NULL,
    td_recovery_cost_unit numeric,
    td_recovery_cost_unit_currency text,
    td_recovery_cost_total numeric,
    td_recovery_cost_total_override boolean DEFAULT false NOT NULL,
    td_disruption_duration_days bigint,
    td_disruption_duration_hours bigint,
    td_disruption_users_affected bigint,
    td_disruption_people_affected bigint,
    td_disruption_description text,
    spatial_footprint jsonb,
    attachments jsonb
);


ALTER TABLE public.damages OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 290215)
-- Name: deaths; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deaths (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dsg_id uuid NOT NULL,
    deaths integer
);


ALTER TABLE public.deaths OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 290219)
-- Name: dev_example1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dev_example1 (
    api_import_id text,
    id bigint NOT NULL,
    field1 text NOT NULL,
    field2 text NOT NULL,
    field3 bigint NOT NULL,
    field4 bigint,
    field6 text DEFAULT 'one'::text NOT NULL,
    field7 timestamp without time zone,
    field8 text DEFAULT ''::text NOT NULL,
    repeatable_num1 integer,
    repeatable_text1 text,
    repeatable_num2 integer,
    repeatable_text2 text,
    repeatable_num3 integer,
    repeatable_text3 text,
    json_data jsonb
);


ALTER TABLE public.dev_example1 OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 290226)
-- Name: dev_example1_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dev_example1_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dev_example1_id_seq OWNER TO postgres;

--
-- TOC entry 6259 (class 0 OID 0)
-- Dependencies: 235
-- Name: dev_example1_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dev_example1_id_seq OWNED BY public.dev_example1.id;


--
-- TOC entry 236 (class 1259 OID 290227)
-- Name: disaster_event; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.disaster_event (
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "approvalStatus" text DEFAULT 'draft'::text NOT NULL,
    api_import_id text,
    hip_hazard_id text,
    hip_cluster_id text,
    hip_type_id text,
    id uuid NOT NULL,
    hazardous_event_id uuid,
    disaster_event_id uuid,
    national_disaster_id text DEFAULT ''::text NOT NULL,
    other_id1 text DEFAULT ''::text NOT NULL,
    other_id2 text DEFAULT ''::text NOT NULL,
    other_id3 text DEFAULT ''::text NOT NULL,
    name_national text DEFAULT ''::text NOT NULL,
    glide text DEFAULT ''::text NOT NULL,
    name_global_or_regional text DEFAULT ''::text NOT NULL,
    start_date text DEFAULT ''::text NOT NULL,
    end_date text DEFAULT ''::text NOT NULL,
    start_date_local text,
    end_date_local text,
    duration_days bigint,
    disaster_declaration text DEFAULT 'unknown'::text NOT NULL,
    disaster_declaration_type_and_effect1 text DEFAULT ''::text NOT NULL,
    disaster_declaration_date1 timestamp without time zone,
    disaster_declaration_type_and_effect2 text DEFAULT ''::text NOT NULL,
    disaster_declaration_date2 timestamp without time zone,
    disaster_declaration_type_and_effect3 text DEFAULT ''::text NOT NULL,
    disaster_declaration_date3 timestamp without time zone,
    disaster_declaration_type_and_effect4 text DEFAULT ''::text NOT NULL,
    disaster_declaration_date4 timestamp without time zone,
    disaster_declaration_type_and_effect5 text DEFAULT ''::text NOT NULL,
    disaster_declaration_date5 timestamp without time zone,
    had_official_warning_or_weather_advisory boolean DEFAULT false NOT NULL,
    official_warning_affected_areas text DEFAULT ''::text NOT NULL,
    early_action_description1 text DEFAULT ''::text NOT NULL,
    early_action_date1 timestamp without time zone,
    early_action_description2 text DEFAULT ''::text NOT NULL,
    early_action_date2 timestamp without time zone,
    early_action_description3 text DEFAULT ''::text NOT NULL,
    early_action_date3 timestamp without time zone,
    early_action_description4 text DEFAULT ''::text NOT NULL,
    early_action_date4 timestamp without time zone,
    early_action_description5 text DEFAULT ''::text NOT NULL,
    early_action_date5 timestamp without time zone,
    rapid_or_preliminary_assesment_description1 text,
    rapid_or_preliminary_assessment_date1 timestamp without time zone,
    rapid_or_preliminary_assesment_description2 text,
    rapid_or_preliminary_assessment_date2 timestamp without time zone,
    rapid_or_preliminary_assesment_description3 text,
    rapid_or_preliminary_assessment_date3 timestamp without time zone,
    rapid_or_preliminary_assesment_description4 text,
    rapid_or_preliminary_assessment_date4 timestamp without time zone,
    rapid_or_preliminary_assesment_description5 text,
    rapid_or_preliminary_assessment_date5 timestamp without time zone,
    response_oprations text DEFAULT ''::text NOT NULL,
    post_disaster_assessment_description1 text,
    post_disaster_assessment_date1 timestamp without time zone,
    post_disaster_assessment_description2 text,
    post_disaster_assessment_date2 timestamp without time zone,
    post_disaster_assessment_description3 text,
    post_disaster_assessment_date3 timestamp without time zone,
    post_disaster_assessment_description4 text,
    post_disaster_assessment_date4 timestamp without time zone,
    post_disaster_assessment_description5 text,
    post_disaster_assessment_date5 timestamp without time zone,
    other_assessment_description1 text,
    other_assessment_date1 timestamp without time zone,
    other_assessment_description2 text,
    other_assessment_date2 timestamp without time zone,
    other_assessment_description3 text,
    other_assessment_date3 timestamp without time zone,
    other_assessment_description4 text,
    other_assessment_date4 timestamp without time zone,
    other_assessment_description5 text,
    other_assessment_date5 timestamp without time zone,
    data_source text DEFAULT ''::text NOT NULL,
    recording_institution text DEFAULT ''::text NOT NULL,
    effects_total_usd numeric,
    non_economic_losses text DEFAULT ''::text NOT NULL,
    damages_subtotal_local_currency numeric,
    losses_subtotal_usd numeric,
    response_operations_description text DEFAULT ''::text NOT NULL,
    response_operations_costs_local_currency numeric,
    response_cost_total_local_currency numeric,
    response_cost_total_usd numeric,
    humanitarian_needs_description text DEFAULT ''::text NOT NULL,
    humanitarian_needs_local_currency numeric,
    humanitarian_needs_usd numeric,
    rehabilitation_costs_local_currency_calc numeric,
    rehabilitation_costs_local_currency_override numeric,
    repair_costs_local_currency_calc numeric,
    repair_costs_local_currency_override numeric,
    replacement_costs_local_currency_calc numeric,
    replacement_costs_local_currency_override numeric,
    recovery_needs_local_currency_calc numeric,
    recovery_needs_local_currency_override numeric,
    attachments jsonb,
    spatial_footprint jsonb,
    legacy_data jsonb
);


ALTER TABLE public.disaster_event OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 290263)
-- Name: disaster_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.disaster_records (
    api_import_id text,
    hip_hazard_id text,
    hip_cluster_id text,
    hip_type_id text,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    disaster_event_id uuid,
    location_desc text,
    start_date text,
    end_date text,
    local_warn_inst text,
    primary_data_source text,
    other_data_source text,
    field_assess_date timestamp without time zone,
    assessment_modes text,
    originator_recorder_inst text DEFAULT ''::text NOT NULL,
    validated_by text DEFAULT ''::text NOT NULL,
    checked_by text,
    data_collector text,
    legacy_data jsonb,
    spatial_footprint jsonb,
    attachments jsonb,
    "approvalStatus" text DEFAULT 'draft'::text NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.disaster_records OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 290274)
-- Name: displaced; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.displaced (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dsg_id uuid NOT NULL,
    assisted text,
    timing text,
    duration text,
    as_of timestamp without time zone,
    displaced integer
);


ALTER TABLE public.displaced OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 290280)
-- Name: disruption; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.disruption (
    api_import_id text,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    record_id uuid NOT NULL,
    sector_id bigint NOT NULL,
    duration_days bigint,
    duration_hours bigint,
    users_affected bigint,
    people_affected bigint,
    comment text,
    response_operation text,
    response_cost numeric,
    response_currency text,
    spatial_footprint jsonb,
    attachments jsonb
);


ALTER TABLE public.disruption OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 290286)
-- Name: division; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.division (
    id bigint NOT NULL,
    import_id text,
    national_id text,
    parent_id bigint,
    name jsonb DEFAULT '{}'::jsonb NOT NULL,
    geojson jsonb,
    level bigint,
    geom public.geometry(Geometry,4326) GENERATED ALWAYS AS (public.st_setsrid(public.st_makevalid(public.st_geomfromgeojson((geojson)::text)), 4326)) STORED,
    bbox public.geometry(Geometry,4326) GENERATED ALWAYS AS (public.st_setsrid(public.st_envelope(public.st_setsrid(public.st_makevalid(public.st_geomfromgeojson((geojson)::text)), 4326)), 4326)) STORED,
    spatial_index text GENERATED ALWAYS AS (
CASE
    WHEN (parent_id IS NULL) THEN ('L1-'::text || (id)::text)
    ELSE ((((('L'::text || (level)::text) || '-'::text) || (parent_id)::text) || '-'::text) || (id)::text)
END) STORED,
    CONSTRAINT valid_geom_check CHECK (public.st_isvalid(geom))
);


ALTER TABLE public.division OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 290296)
-- Name: division_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.division_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.division_id_seq OWNER TO postgres;

--
-- TOC entry 6260 (class 0 OID 0)
-- Dependencies: 241
-- Name: division_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.division_id_seq OWNED BY public.division.id;


--
-- TOC entry 242 (class 1259 OID 290297)
-- Name: dts_system_info; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dts_system_info (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    db_version_no character varying(50) NOT NULL,
    app_version_no character varying(50) NOT NULL,
    installed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.dts_system_info OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 290302)
-- Name: event; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text NOT NULL
);


ALTER TABLE public.event OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 290310)
-- Name: event_relationship; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_relationship (
    parent_id uuid NOT NULL,
    child_id uuid NOT NULL,
    type text DEFAULT ''::text NOT NULL
);


ALTER TABLE public.event_relationship OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 290316)
-- Name: hazardous_event; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hazardous_event (
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "approvalStatus" text DEFAULT 'draft'::text NOT NULL,
    api_import_id text,
    hip_hazard_id text,
    hip_cluster_id text,
    hip_type_id text NOT NULL,
    id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    national_specification text DEFAULT ''::text NOT NULL,
    start_date text DEFAULT ''::text NOT NULL,
    end_date text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    chains_explanation text DEFAULT ''::text NOT NULL,
    magniture text DEFAULT ''::text NOT NULL,
    spatial_footprint jsonb,
    attachments jsonb,
    record_originator text DEFAULT ''::text NOT NULL,
    hazardous_event_status text,
    data_source text DEFAULT ''::text NOT NULL
);


ALTER TABLE public.hazardous_event OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 290333)
-- Name: hip_class; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hip_class (
    id text NOT NULL,
    name_en text DEFAULT ''::text NOT NULL,
    CONSTRAINT name_en_not_empty CHECK ((name_en <> ''::text))
);


ALTER TABLE public.hip_class OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 290340)
-- Name: hip_cluster; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hip_cluster (
    id text NOT NULL,
    type_id text NOT NULL,
    name_en text DEFAULT ''::text NOT NULL,
    CONSTRAINT name_en_not_empty CHECK ((name_en <> ''::text))
);


ALTER TABLE public.hip_cluster OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 290347)
-- Name: hip_hazard; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hip_hazard (
    id text NOT NULL,
    code text DEFAULT ''::text NOT NULL,
    cluster_id text NOT NULL,
    name_en text DEFAULT ''::text NOT NULL,
    description_en text DEFAULT ''::text NOT NULL,
    CONSTRAINT description_en_not_empty CHECK ((description_en <> ''::text)),
    CONSTRAINT name_en_not_empty CHECK ((name_en <> ''::text))
);


ALTER TABLE public.hip_hazard OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 290357)
-- Name: human_category_presence; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.human_category_presence (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    record_id uuid NOT NULL,
    deaths boolean,
    injured boolean,
    missing boolean,
    affected_direct boolean,
    affected_indirect boolean,
    displaced boolean
);


ALTER TABLE public.human_category_presence OWNER TO postgres;

--
-- TOC entry 250 (class 1259 OID 290361)
-- Name: human_dsg; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.human_dsg (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    record_id uuid NOT NULL,
    sex text,
    age text,
    disability text,
    global_poverty_line text,
    national_poverty_line text,
    custom jsonb
);


ALTER TABLE public.human_dsg OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 290367)
-- Name: human_dsg_config; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.human_dsg_config (
    hidden jsonb,
    custom jsonb
);


ALTER TABLE public.human_dsg_config OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 290372)
-- Name: injured; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.injured (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dsg_id uuid NOT NULL,
    injured integer
);


ALTER TABLE public.injured OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 290376)
-- Name: instance_system_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instance_system_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    footer_url_privacy_policy character varying,
    footer_url_terms_conditions character varying,
    admin_setup_complete boolean DEFAULT false NOT NULL
);


ALTER TABLE public.instance_system_settings OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 290383)
-- Name: losses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.losses (
    api_import_id text,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    record_id uuid NOT NULL,
    sector_id bigint NOT NULL,
    sector_is_agriculture boolean NOT NULL,
    type_not_agriculture text,
    type_agriculture text,
    related_to_not_agriculture text,
    related_to_agriculture text,
    description text,
    public_value_unit text,
    public_units bigint,
    public_cost_unit numeric,
    public_cost_unit_currency text,
    public_cost_total numeric,
    public_cost_total_override boolean DEFAULT false NOT NULL,
    private_value_unit text,
    private_units bigint,
    private_cost_unit numeric,
    private_cost_unit_currency text,
    private_cost_total numeric,
    private_cost_total_override boolean DEFAULT false NOT NULL,
    spatial_footprint jsonb,
    attachments jsonb
);


ALTER TABLE public.losses OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 290391)
-- Name: measure; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.measure (
    api_import_id text,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    type text DEFAULT 'area'::text NOT NULL
);


ALTER TABLE public.measure OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 290398)
-- Name: missing; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.missing (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dsg_id uuid NOT NULL,
    as_of timestamp without time zone,
    missing integer
);


ALTER TABLE public.missing OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 290402)
-- Name: noneco_losses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.noneco_losses (
    api_import_id text,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    disaster_record_id uuid NOT NULL,
    category_id bigint NOT NULL,
    description text NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.noneco_losses OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 290410)
-- Name: sector; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sector (
    id bigint NOT NULL,
    parent_id bigint,
    sectorname text NOT NULL,
    description text,
    level bigint DEFAULT 1 NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.sector OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 290418)
-- Name: sector_disaster_records_relation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sector_disaster_records_relation (
    api_import_id text,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sector_id bigint NOT NULL,
    disaster_record_id uuid NOT NULL,
    with_damage boolean,
    damage_cost numeric,
    damage_cost_currency text,
    damage_recovery_cost numeric,
    damage_recovery_cost_currency text,
    with_disruption boolean,
    with_losses boolean,
    losses_cost numeric,
    losses_cost_currency text
);


ALTER TABLE public.sector_disaster_records_relation OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 290424)
-- Name: sector_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sector_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sector_id_seq OWNER TO postgres;

--
-- TOC entry 6261 (class 0 OID 0)
-- Dependencies: 260
-- Name: sector_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sector_id_seq OWNED BY public.sector.id;


--
-- TOC entry 261 (class 1259 OID 290425)
-- Name: session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    last_active_at timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    totp_authed boolean DEFAULT false NOT NULL
);


ALTER TABLE public.session OWNER TO postgres;

--
-- TOC entry 262 (class 1259 OID 290431)
-- Name: unit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.unit (
    api_import_id text,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type text DEFAULT 'area'::text NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.unit OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 290438)
-- Name: user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."user" (
    id bigint NOT NULL,
    role text DEFAULT ''::text NOT NULL,
    first_name text DEFAULT ''::text NOT NULL,
    last_name text DEFAULT ''::text NOT NULL,
    email text NOT NULL,
    password text DEFAULT ''::text NOT NULL,
    email_verified boolean DEFAULT false NOT NULL,
    email_verification_code text DEFAULT ''::text NOT NULL,
    email_verification_sent_at timestamp without time zone,
    email_verification_expires_at timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    invite_code text DEFAULT ''::text NOT NULL,
    invite_sent_at timestamp without time zone,
    invite_expires_at timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    reset_password_token text DEFAULT ''::text NOT NULL,
    reset_password_expires_at timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    totp_enabled boolean DEFAULT false NOT NULL,
    totp_secret text DEFAULT ''::text NOT NULL,
    totp_secret_url text DEFAULT ''::text NOT NULL,
    organization text DEFAULT ''::text NOT NULL,
    hydromet_che_user boolean DEFAULT false NOT NULL,
    auth_type text DEFAULT 'form'::text NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."user" OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 290462)
-- Name: user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_id_seq OWNER TO postgres;

--
-- TOC entry 6262 (class 0 OID 0)
-- Dependencies: 264
-- Name: user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_id_seq OWNED BY public."user".id;


--
-- TOC entry 5761 (class 2604 OID 290463)
-- Name: __drizzle_migrations__ id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.__drizzle_migrations__ ALTER COLUMN id SET DEFAULT nextval('public.__drizzle_migrations___id_seq'::regclass);


--
-- TOC entry 5765 (class 2604 OID 290464)
-- Name: api_key id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_key ALTER COLUMN id SET DEFAULT nextval('public.api_key_id_seq'::regclass);


--
-- TOC entry 5770 (class 2604 OID 290465)
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- TOC entry 5774 (class 2604 OID 290466)
-- Name: country1 id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.country1 ALTER COLUMN id SET DEFAULT nextval('public.country1_id_seq'::regclass);


--
-- TOC entry 5785 (class 2604 OID 290467)
-- Name: dev_example1 id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dev_example1 ALTER COLUMN id SET DEFAULT nextval('public.dev_example1_id_seq'::regclass);


--
-- TOC entry 5827 (class 2604 OID 290468)
-- Name: division id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.division ALTER COLUMN id SET DEFAULT nextval('public.division_id_seq'::regclass);


--
-- TOC entry 5869 (class 2604 OID 290469)
-- Name: sector id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sector ALTER COLUMN id SET DEFAULT nextval('public.sector_id_seq'::regclass);


--
-- TOC entry 5879 (class 2604 OID 290470)
-- Name: user id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."user" ALTER COLUMN id SET DEFAULT nextval('public.user_id_seq'::regclass);


--
-- TOC entry 6205 (class 0 OID 290154)
-- Dependencies: 221
-- Data for Name: __drizzle_migrations__; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.__drizzle_migrations__ (id, hash, created_at) FROM stdin;
\.


--
-- TOC entry 6207 (class 0 OID 290160)
-- Dependencies: 223
-- Data for Name: affected; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.affected (id, dsg_id, direct, indirect) FROM stdin;
\.


--
-- TOC entry 6208 (class 0 OID 290164)
-- Dependencies: 224
-- Data for Name: api_key; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.api_key (updated_at, created_at, id, secret, name, user_id) FROM stdin;
2025-07-16 12:15:40.243164	2025-07-16 17:15:40.243	1	51698ee443fc9d21093cd1891fc8a34c0316fa8667c4fb5b265cd15a527feef3	DIX	1
\.


--
-- TOC entry 6210 (class 0 OID 290173)
-- Dependencies: 226
-- Data for Name: asset; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.asset (api_import_id, id, sector_ids, is_built_in, name, category, national_id, notes) FROM stdin;
\.


--
-- TOC entry 6211 (class 0 OID 290179)
-- Dependencies: 227
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (id, table_name, record_id, user_id, action, old_values, new_values, "timestamp") FROM stdin;
\.


--
-- TOC entry 6212 (class 0 OID 290186)
-- Dependencies: 228
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categories (id, name, parent_id, level, updated_at, created_at) FROM stdin;
\.


--
-- TOC entry 6214 (class 0 OID 290195)
-- Dependencies: 230
-- Data for Name: country1; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.country1 (id, name) FROM stdin;
\.


--
-- TOC entry 6216 (class 0 OID 290202)
-- Dependencies: 232
-- Data for Name: damages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.damages (api_import_id, id, record_id, sector_id, asset_id, unit, total_damage_amount, total_damage_amount_override, total_repair_replacement, total_repair_replacement_override, total_recovery, total_recovery_override, pd_damage_amount, pd_repair_cost_unit, pd_repair_cost_unit_currency, pd_repair_cost_total, pd_repair_cost_total_override, pd_recovery_cost_unit, pd_recovery_cost_unit_currency, pd_recovery_cost_total, pd_recovery_cost_total_override, pd_disruption_duration_days, pd_disruption_duration_hours, pd_disruption_users_affected, pd_disruption_people_affected, pd_disruption_description, td_damage_amount, td_replacement_cost_unit, td_replacement_cost_unit_currency, td_replacement_cost_total, td_replacement_cost_total_override, td_recovery_cost_unit, td_recovery_cost_unit_currency, td_recovery_cost_total, td_recovery_cost_total_override, td_disruption_duration_days, td_disruption_duration_hours, td_disruption_users_affected, td_disruption_people_affected, td_disruption_description, spatial_footprint, attachments) FROM stdin;
\.


--
-- TOC entry 6217 (class 0 OID 290215)
-- Dependencies: 233
-- Data for Name: deaths; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deaths (id, dsg_id, deaths) FROM stdin;
\.


--
-- TOC entry 6218 (class 0 OID 290219)
-- Dependencies: 234
-- Data for Name: dev_example1; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dev_example1 (api_import_id, id, field1, field2, field3, field4, field6, field7, field8, repeatable_num1, repeatable_text1, repeatable_num2, repeatable_text2, repeatable_num3, repeatable_text3, json_data) FROM stdin;
\.


--
-- TOC entry 6220 (class 0 OID 290227)
-- Dependencies: 236
-- Data for Name: disaster_event; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.disaster_event (updated_at, created_at, "approvalStatus", api_import_id, hip_hazard_id, hip_cluster_id, hip_type_id, id, hazardous_event_id, disaster_event_id, national_disaster_id, other_id1, other_id2, other_id3, name_national, glide, name_global_or_regional, start_date, end_date, start_date_local, end_date_local, duration_days, disaster_declaration, disaster_declaration_type_and_effect1, disaster_declaration_date1, disaster_declaration_type_and_effect2, disaster_declaration_date2, disaster_declaration_type_and_effect3, disaster_declaration_date3, disaster_declaration_type_and_effect4, disaster_declaration_date4, disaster_declaration_type_and_effect5, disaster_declaration_date5, had_official_warning_or_weather_advisory, official_warning_affected_areas, early_action_description1, early_action_date1, early_action_description2, early_action_date2, early_action_description3, early_action_date3, early_action_description4, early_action_date4, early_action_description5, early_action_date5, rapid_or_preliminary_assesment_description1, rapid_or_preliminary_assessment_date1, rapid_or_preliminary_assesment_description2, rapid_or_preliminary_assessment_date2, rapid_or_preliminary_assesment_description3, rapid_or_preliminary_assessment_date3, rapid_or_preliminary_assesment_description4, rapid_or_preliminary_assessment_date4, rapid_or_preliminary_assesment_description5, rapid_or_preliminary_assessment_date5, response_oprations, post_disaster_assessment_description1, post_disaster_assessment_date1, post_disaster_assessment_description2, post_disaster_assessment_date2, post_disaster_assessment_description3, post_disaster_assessment_date3, post_disaster_assessment_description4, post_disaster_assessment_date4, post_disaster_assessment_description5, post_disaster_assessment_date5, other_assessment_description1, other_assessment_date1, other_assessment_description2, other_assessment_date2, other_assessment_description3, other_assessment_date3, other_assessment_description4, other_assessment_date4, other_assessment_description5, other_assessment_date5, data_source, recording_institution, effects_total_usd, non_economic_losses, damages_subtotal_local_currency, losses_subtotal_usd, response_operations_description, response_operations_costs_local_currency, response_cost_total_local_currency, response_cost_total_usd, humanitarian_needs_description, humanitarian_needs_local_currency, humanitarian_needs_usd, rehabilitation_costs_local_currency_calc, rehabilitation_costs_local_currency_override, repair_costs_local_currency_calc, repair_costs_local_currency_override, replacement_costs_local_currency_calc, replacement_costs_local_currency_override, recovery_needs_local_currency_calc, recovery_needs_local_currency_override, attachments, spatial_footprint, legacy_data) FROM stdin;
\.


--
-- TOC entry 6221 (class 0 OID 290263)
-- Dependencies: 237
-- Data for Name: disaster_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.disaster_records (api_import_id, hip_hazard_id, hip_cluster_id, hip_type_id, id, disaster_event_id, location_desc, start_date, end_date, local_warn_inst, primary_data_source, other_data_source, field_assess_date, assessment_modes, originator_recorder_inst, validated_by, checked_by, data_collector, legacy_data, spatial_footprint, attachments, "approvalStatus", updated_at, created_at) FROM stdin;
\.


--
-- TOC entry 6222 (class 0 OID 290274)
-- Dependencies: 238
-- Data for Name: displaced; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.displaced (id, dsg_id, assisted, timing, duration, as_of, displaced) FROM stdin;
\.


--
-- TOC entry 6223 (class 0 OID 290280)
-- Dependencies: 239
-- Data for Name: disruption; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.disruption (api_import_id, id, record_id, sector_id, duration_days, duration_hours, users_affected, people_affected, comment, response_operation, response_cost, response_currency, spatial_footprint, attachments) FROM stdin;
\.


--
-- TOC entry 6224 (class 0 OID 290286)
-- Dependencies: 240
-- Data for Name: division; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.division (id, import_id, national_id, parent_id, name, geojson, level) FROM stdin;
\.


--
-- TOC entry 6226 (class 0 OID 290297)
-- Dependencies: 242
-- Data for Name: dts_system_info; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dts_system_info (id, db_version_no, app_version_no, installed_at) FROM stdin;
\.


--
-- TOC entry 6227 (class 0 OID 290302)
-- Dependencies: 243
-- Data for Name: event; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.event (id, name, description) FROM stdin;
\.


--
-- TOC entry 6228 (class 0 OID 290310)
-- Dependencies: 244
-- Data for Name: event_relationship; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.event_relationship (parent_id, child_id, type) FROM stdin;
\.


--
-- TOC entry 6229 (class 0 OID 290316)
-- Dependencies: 245
-- Data for Name: hazardous_event; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hazardous_event (updated_at, created_at, "approvalStatus", api_import_id, hip_hazard_id, hip_cluster_id, hip_type_id, id, status, national_specification, start_date, end_date, description, chains_explanation, magniture, spatial_footprint, attachments, record_originator, hazardous_event_status, data_source) FROM stdin;
\.


--
-- TOC entry 6230 (class 0 OID 290333)
-- Dependencies: 246
-- Data for Name: hip_class; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hip_class (id, name_en) FROM stdin;
1041	Geohazards
1044	Technological
1042	Meteorological and Hydrological
1037	Biological
1043	Societal
1038	Chemical
1039	Environmental
1040	Extraterrestrial
\.


--
-- TOC entry 6231 (class 0 OID 290340)
-- Dependencies: 247
-- Data for Name: hip_cluster; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hip_cluster (id, type_id, name_en) FROM stdin;
1045	1037	Fisheries and Aquaculture
1046	1037	Insect Infestation
1047	1037	Invasive Species
1048	1037	Human Animal Interaction
1049	1037	CBRNE (Chemical, Biological, Radiological, Nuclear and Explosive)
1050	1037	Mental Health
1051	1037	Food Safety
1057	1038	Heavy Metals
1052	1037	Infectious Diseases (Plant)
1058	1038	Food Safety
1059	1038	Pesticides
1060	1038	Persistent Organic Pollutants (POPs)
1061	1038	Hydrocarbons
1062	1038	CBRNE (Chemical, Biological, Radiological, Nuclear and Explosive)
1093	1044	Transportation
1063	1038	Other Chemical Hazards and Toxins
1064	1038	Fisheries and Aquaculture
1088	1044	Cyber Hazard
1074	1042	Marine
1075	1042	Pressure Related
1076	1042	Precipitation Related
1065	1039	Environmental Degradation
1066	1039	Environmental Degradation (Forestry)
1077	1042	Temperature Related
1078	1042	Terrestrial
1067	1040	Extraterrestrial
1068	1041	Seismogenic (Earthquakes)
1079	1042	Wind Related
1080	1043	Conflict
1081	1043	Post Conflict
1082	1043	Behavioural
1053	1037	Infectious Diseases (Human and Animal)
1083	1043	Economic
1054	1037	Infectious Diseases (Animal)
1055	1037	Infectious Diseases (Aquaculture)
1069	1041	Volcanogenic
1056	1038	Gases
1084	1044	Radiation
1085	1044	CBRNE (Chemical, Biological, Radiological, Nuclear and Explosive)
1086	1044	Structural Failure
1070	1041	Other Geohazard
1071	1042	Convective Related
1087	1044	Infrastructure Failure
1072	1042	Flood
1073	1042	Lithometeors
1089	1044	Industrial Failure
1090	1044	Waste
1091	1044	Marine
1092	1044	Flood
\.


--
-- TOC entry 6232 (class 0 OID 290347)
-- Dependencies: 248
-- Data for Name: hip_hazard; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hip_hazard (id, code, cluster_id, name_en, description_en) FROM stdin;
78385	BI0001	1045	Harmful Algal Blooms	Harmful algal blooms result from noxious and/or toxic algae that cause direct and indirect negative impacts on aquatic ecosystems, coastal resources, and human health (Kudela et al., 2015).
78386	BI0002	1046	Insect Pest Infestations	An insect pest infestation is a recently detected insect pest population, including an incursion, or a sudden significant increase of an established insect, disease agents or weed population in an area leading to damage to plants in production fields, forests or natural habitats and causing substantial damage to productivity, biodiversity or natural resources (adapted from FAO, 2019).
78387	BI0003	1046	Locust	Widespread and heavy infestations of crops and natural vegetation by locusts causing significant threats to food security, livelihoods and natural habitats in multiple regions (adapted from FAO, 2009).
78388	BI0004	1047	Invasive Weeds	An invasive weed is an alien species that by its establishment or spread has become injurious to plants, or that by risk analysis is shown to be potentially injurious to plants (adapted from FAO, 2017).
78389	BI0005	1047	Invasive Species	‘Invasive species’, also known as ‘alien invasive species’, are species whose introduction, establishment and spread into new areas threaten ecosystems, habitats or other species and cause social, economic or environmental harm, or harm to human health (FAO, 2007:82).
78390	BI0006	1048	Snake Envenomation	A snake envenomation is a potentially life-threatening disease caused by toxins in the bite of a venomous snake. Envenoming can also be caused by having venom sprayed into the eyes by certain species of snake that have the ability to spit venom as a defence measure (WHO, no date).
78391	BI0007	1048	Human-Wildlife Conflict	Human-wildlife conflict is defined as struggles that emerge when the presence or behaviour of wildlife poses an actual or perceived, direct and recurring threat to human interests or needs, leading to disagreements between groups of people and negative impacts on people and/or wildlife (IUCN SSC, 2020).
78392	BI0008	1049	Biological Agents	Biological agents, according to the Convention on the Prohibition of the Development, Production and Stockpiling of Bacteriological (Biological) and Toxin Weapons and on their Destruction (1972), include germs, toxins and viruses that can sicken or kill people, livestock, or crops (UNODA, 1972).
78393	BI0009	1050	Suicide Cluster	The term ‘suicide cluster’ describes a situation in which more suicides than expected occur in terms of time, place, or both. It is difficult to precisely define a cluster. A suicide cluster usually includes three or more deaths; however, two suicides occurring in a specific community or setting (for example a school) in a short time period should also be taken very seriously in terms of possible links and impacts (even if the deaths are apparently unconnected), particularly in the case of young people (PHE, 2019).
78394	BI0010	1051	Antimicrobial Resistance	Antimicrobial resistance is the ability of a microorganism to multiply or persist in the presence of an increased level of an antimicrobial agent relative to the susceptible counterpart of the same species (FAO, 2011).
78395	BI0011	1051	Foodborne Microbial Hazards (including human enteric virus and foodborne parasite)	<p>Foodborne microbial hazards include (but are not limited to) pathogenic bacteria, viruses, algae, protozoa, fungi, parasites, prions, toxins and other harmful metabolites of microbial origin (FAO and WHO, 2007).</p><p>A human enteric virus is a virus that replicates in the gastro-intestinal tract or in the liver and is excreted in faeces and/or vomitus from humans. It is transmitted mainly by the faecal-oral route and is infectious to humans (FAO and WHO, 2012).</p><p>A foodborne parasite is any parasite that can be transmitted to humans by ingesting food (FAO and WHO, 2016).</p>
78396	BI0012	1052	Bacterial Plant Disease	A bacterial plant disease is the occurrence of plant diseases caused by bacterial microorganisms over large areas with significant impacts on crop and forest productivity or natural habitat (adapted from FAO, 2018).
78397	BI0013	1052	Fungal Plant Disease	Fungal plant disease is the occurrence of plant diseases caused by fungal agents over large areas with significant impact on crop productivity or natural habitats (Arneson, 2001; Moore et al., 2019).
78398	BI0014	1052	Viral, Mycoplasma and Viroid Plant Disease	Viral, mycoplasma and viroid plant disease epidemics are the occurrence of plant diseases caused by viruses, mycoplasma (syn. phytoplasma, mycoplasma-like organisms ) and viroids over large areas with significant impact on crop productivity or natural habitats (adapted from Nakashima and Murata, 1993; Hammond and Owens, 2006; FAO and IPPC, 2016; Rubio et al., 2020).
78399	BI0015	1053	Anthrax	Anthrax is a disease caused by the spore-forming bacteria Bacillus anthracis. Anthrax is primarily a disease of herbivorous animals, although all mammals, including humans can contract it. In humans, anthrax manifests itself in three distinct patterns (cutaneous, gastrointestinal, inhalational) (adapted from WHO, FAO and OIE, 2008; CDC, 2020).
78400	BI0016	1053	Airborne Diseases	Airborne transmission of infectious agents refers to the transmission of disease caused by dissemination of very small droplets that remain infectious when suspended in air over long distance and time (WHO, 2020).
78401	BI0017	1053	Blood Borne Viruses	Blood-borne viruses are viruses transmitted by direct contact with infected blood or other body fluids (WHO, 2012).
78402	BI0018	1053	Waterborne Diseases	<p>Waterborne diseases are those diseases that are transmitted by ingestion of contaminated water (WHO, 2012).</p>
78403	BI0019	1053	Foodborne Diseases	Foodborne diseases are transmitted by consumption of contaminated biological food and drink (WHO, 2012). These diseases are caused by eating food contaminated with bacteria, viruses, parasites or chemical substances (WHO, no date).
78404	BI0020	1053	Sexually Transmitted Diseases (Human)	Sexually transmitted diseases are infections transmitted from an infected person to an uninfected person through sexual contact (WHO, no date).
78405	BI0021	1053	Neglected Tropical Diseases (Human)	Neglected tropical diseases (NTDs) are a diverse group of communicable diseases caused by bacteria, viruses or parasites that prevail in tropical and subtropical conditions (WHO, no date). Twenty diseases and disease groups are addressed in the global roadmap for NTDs 2021–2030 (WHO, 2020).
78406	BI0022	1053	Vaccine-Preventable Diseases (Human)	Vaccine preventable diseases are those infectious diseases that can be prevented by vaccination (WHO, 2012).
78453	BI0069	1053	Rotavirus (Human)	Rotaviruses are the most common cause of severe diarrhoeal disease in young children throughout the world. According to WHO estimates in 2013 about 215,000 children aged under 5 years die each year from vaccine-preventable rotavirus infections; the vast majority of these children live in low-income countries (WHO, 2018).
78407	BI0023	1053	Vector Borne Diseases (VBD) (Human)	Vector borne diseases encompass a variety of illnesses that are caused via the spread of pathogens by living organisms known as vectors. These infectious diseases can be transmitted via vectors among humans (e.g., malaria, dengue), among animals (e.g., African swine fever, East Coast fever), or from animals to humans (e.g., Nipah virus disease). Many of these vectors are bloodsucking insects, and mosquitoes are the bestknown disease vector. Other vectors include ticks, flies, sandflies, fleas, triatomine bugs and some species of freshwater aquatic snails (adapted from OIE, 2019; WHO, 2020).
78408	BI0024	1053	Viral Haemorrhagic Fevers (Human)	Viral haemorrhagic fever is a general term for severe illnesses, sometimes associated with bleeding, that may be caused by a number of viruses. The term is usually applied to diseases caused by viruses that belong to the Arenaviridae, Bunyaviridae, Filoviridae and Flaviviridae families (WHO, no date).
78409	BI0025	1053	Antimicrobial Resistant Microorganisms	Antimicrobial resistant microorganisms are those microorganisms (such as bacteria, fungi, viruses, and parasites) that change when they are exposed to antimicrobial drugs (such as antibiotics, antifungals, antivirals, antimalarials, and anthelmintic). Microorganisms that develop antimicrobial resistance are sometimes referred to as ‘superbugs’. As a result, the medicines become ineffective and infections persist in the body, increasing the risk of spread to others (WHO, 2020).
78410	BI0026	1053	Animal Diseases (Not Zoonoses)	Animal disease is an impairment of the normal state of an animal that interrupts or modifies its vital function. Infectious diseases of livestock and wildlife are a major threat to global animal health and welfare and their effective control is crucial for agronomic health, for safeguarding and securing national and international food supplies and for alleviating rural poverty in developing countries. This hazard information profile focusses on animal diseases not including zoonoses (Britannica, 2021; adapted from Tomley and Shirley, 2009).
78411	BI0027	1053	Zoonotic Diseases	Zoonotic diseases are a group of communicable diseases that are transmissible from vertebrate animals to humans through direct contact or through food, water, and the environment (WHO, no date).
78412	BI0028	1053	Diarrhoeal Diseases (Human)	Diarrhoeal diseases are infectious diseases, contaminants and other causes of diarrhoea. Diarrhoea is defined as the passage of three or more loose or liquid stools per day, or more frequently than is normal for the individual (WHO, no date). This includes the three clinical types of diarrhoea: acute watery diarrhoea – lasts several hours or days, and includes cholera; acute bloody diarrhoea – also called dysentery; and persistent diarrhoea – lasts 14 days or longer (WHO, 2017).
78413	BI0029	1053	Prion Diseases	Prion diseases are a family of rare progressive neurodegenerative disorders that affect both humans and animals (CDC, no date).
78414	BI0030	1053	Hepatitis B (Human)	Hepatitis B is a vaccine-preventable disease, that is endemic and epidemic worldwide, and caused by the Hepatitis B virus (HBV). HBV can cause both acute and chronic liver disease. Chronic infection puts people at high risk of death from cirrhosis and liver cancer (WHO, 2020).
78415	BI0031	1053	Hepatitis C (human)	Hepatitis C is a blood-borne liver disease caused by the hepatitis C virus: the virus can cause both acute and chronic hepatitis, ranging in severity from a mild illness lasting a few weeks to a serious, lifelong illness including liver cirrhosis and liver cancer. Hepatitis C is endemic and epidemic worldwide (WHO, 2020).
78416	BI0032	1053	HIV and AIDS (Human)	The human immunodeficiency virus (HIV) is a viral sexually transmitted and blood-borne infection which targets the immune system, weakening people’s defences against opportunistic infections and some types of cancer. The most advanced stage of HIV infection is acquired immunodeficiency syndrome (AIDS), which can take from 2 to 15 years to develop if not treated, depending on the individual. AIDS is defined by the development of certain cancers, infections or other severe clinical manifestations (WHO, 2019).
78417	BI0033	1053	COVID-19 (SARS-CoV-2) (Human)	COVID-19 is an infectious disease caused by the SARS Coronavirus 2 (SARS CoC2), a virus first identified in human populations in late 2019. Transmission occurs through droplets containing infectious virus, either by direct face to face contact (splash) generated by speaking, singing, coughing or sneezing; or by aerosolisation for up to 1 metre. Virus-containing aerosols that travel further than 1 metre are defined as airborne. The virus is thought to infect humans through the mucus membranes of the eyes, nose and mouth. Living virus has been isolated from faeces and urine but neither is thought to represent a major means of transmission. Fomites are thought to represent a low risk of transmission, but the risk has not yet been quantified. The risk of transmission is greatest in closed, poorly ventilated spaces where humans are in close proximity for ten to fifteen minutes and do not physically distance or wear a protective face covering (WHO, 2020).
78418	BI0034	1053	Cholera (Human)	Cholera is an acute diarrhoeal infection caused by ingestion of food or water contaminated with the bacterium Vibrio cholerae. Cholera remains a global threat to public health (WHO, 2019).
78419	BI0035	1053	Cryptosporidium (Human)	Cryptosporidium is a microscopic parasite that causes the watery diarrhoeal disease cryptosporidiosis (WHO, 2013).
78420	BI0036	1053	Paratyphoid fever (Human)	Paratyphoid fever is a systemic disease caused by the bacterium Salmonella Paratyphi usually through ingestion of contaminated food or water (WHO, 2019).
78421	BI0037	1053	Typhoid Fever (Human)	Typhoid fever is a life-threatening infection caused by the bacterium Salmonella Typhi. It is usually spread through contaminated food or water. An estimated 11–20 million people get sick from typhoid and between 128,000 and 161,000 people die from it every year (WHO, 2018).
78422	BI0038	1053	Hepatitis A (Human)	Hepatitis A is an acute vaccine-preventable viral liver disease caused by the hepatitis A virus. The infection can cause mild to severe illness and is epidemic prone (WHO, 2020).
78423	BI0039	1053	Escherichia Coli (STEC) (Human)	Escherichia coli (E. coli) is a bacterium commonly found in the gut. Some strains can cause serious food poisoning, leading to diarrhoea and sometimes to life-threatening complications including haemolytic uraemic syndrome (WHO, 2018).
78424	BI0040	1053	Listeriosis (Human)	Listeriosis is a foodborne infection caused by the bacterium Listeria monocytogenes which can be invasive (the more serious form of the disease) or non-invasive (the milder form of the disease). Listeriosis outbreaks occur in all countries and can be a significant public health concern (WHO, 2018).
78425	BI0041	1053	Shigellosis (Human)	Shigellosis is an acute invasive enteric infection caused by bacteria belonging to genus Shigella (WHO, 2005).
78454	BI0071	1053	Vector-borne diseases (VBD) (Animals)	Vector-borne diseases are diseases transmitted by a living being, usually an arthropod vector, to a vertebrate host (Verwoerd, 2015).
78426	BI0042	1053	Avian Influenza (Human and Animal)	Avian influenza is an infectious disease of birds caused by type A influenza viruses of the Orthomyxoviridae family. Naturally occurring among wild bird populations, avian influenza viruses can infect domestic poultry and other bird species. Some avian influenza viruses can also infect mammals and those affecting humans are called zoonotic. A pandemic can occur when a novel zoonotic avian influenza virus spreads in human populations worldwide (FAO, 2009; WHO, 2018; OIE, 2020).
78427	BI0043	1053	Pandemic Influenza (Human)	An influenza pandemic is the worldwide spread of a new influenza virus to which there is little or no pre-existing immunity in the human population (WHO, 2021).
78428	BI0044	1053	Seasonal Influenza (Human)	Seasonal influenza is an acute respiratory infection caused by influenza viruses which circulate in all parts of the world (WHO, 2018).
78429	BI0045	1053	Cysticercosis	Cysticercosis is a preventable intestinal infection in humans and animals caused by the tapeworm Taenia solium (pork tapeworm). Human cysticercosisi can result in devastating effects on human health resulting in neurocysticercosis with blindness, convulsions, and epileptic seizures, and can be fatal. It is estimated to affect between 2.56 and 8.30 million people, based on the range of epilepsy prevalence data available (adapted from WHO, 2020).
78430	BI0046	1053	Leptospirosis (Human)	Leptospirosis is an infectious disease caused by pathogenic Spirochaetes of the genus Leptospira. These bacteria called leptospires affect both humans and animals. Humans become infected through direct contact with the urine of infected animals or with a urinecontaminated environment. It is a zoonosis. Human-to-human transmission occurs only very rarely (adapted from WHO and ILS, 2003 and WHO, 2020).
78431	BI0047	1053	Plague (Human)	Plague is an acute febrile infectious disease caused by the zoonotic bacteria Yersinia pestis (Dennis et al., 1999).
78432	BI0048	1053	Leprosy	Leprosy is a curable infectious disease, endemic in many countries, caused by the bacterium Mycobacterium leprae (M. leprae). It mainly affects the skin, peripheral nerves, mucosa of the upper respiratory tract and eyes. Untreated, it can lead to permanent disability (WHO, 2019).
78433	BI0049	1053	Chikungunya	Chikungunya is a mosquito-borne viral infection caused by the chikungunya virus. It causes fever and severe arthralgia (joint pain) which is often debilitating. The disease can be endemic and epidemic in countries (WHO, 2020).
78434	BI0050	1053	Zika Virus (human)	Zika virus disease is a disease transmitted primarily by Aedes mosquitoes which can lead to complications (WHO, 2018).
78435	BI0051	1053	Diphtheria (Human)	Diphtheria is a widespread severe infectious disease caused by the bacterium Corynebacterium diphtheriae and the toxin they produce. It is a potentially life-threatening, vaccine-preventable disease that primarily affects the throat and upper airways and has the potential for epidemics (WHO, 2018).
78436	BI0052	1053	Measles (Human)	Measles is a highly contagious, serious disease caused by a virus from the paramyxovirus family. Transmission occurs through direct contact, droplet spread, and airborne spread. The virus initially infects the respiratory tract, then spreads throughout the body (WHO 2019).
78437	BI0053	1053	Meningococcal Meningitis (Human)	Meningococcal meningitis is a bacterial form of meningitis, a serious infection of the thin lining that surrounds the brain and spinal cord, that is caused by the bacterium Neisseria meningitidis. Meningococcal meningitis has the potential to cause large-scale epidemics and is observed worldwide (WHO, 2018).
78438	BI0054	1053	Pertussis (Human)	Pertussis is a highly contagious disease of the respiratory tract caused by the bacterium Bordetella pertussis (WHO, no date).
78439	BI0055	1053	Polio (Human)	Polio (human) is a highly infectious viral disease which mainly affects young children (WHO, 2019).
78440	BI0056	1053	Smallpox (Human)	Smallpox is an acute contagious disease caused by the variola virus (WHO, 2019).
78441	BI0057	1053	Varicella and herpes zoster (Human)	Varicella is an acute, highly contagious disease caused by varicellazoster virus (WHO, 2014).
78442	BI0058	1053	Yellow Fever (Human)	Yellow fever is an acute viral haemorrhagic disease transmitted by infected mosquitoes (WHO, 2019).
78443	BI0059	1053	Dengue (Human)	Dengue is a mosquito-borne disease that is caused by a virus of the Flaviviridae family and transmitted by female mosquitoes mainly of the species Aedes aegypti and, to a lesser extent, A. albopictus (WHO, 2020).
78444	BI0060	1053	Malaria (Human)	Malaria is a life-threatening disease caused by parasites that are transmitted to people through the bites of infected female Anopheles mosquitoes. It is preventable and curable. In 2018, there were an estimated 228 million cases of malaria worldwide and the estimated number of malaria deaths stood at 405,000 (WHO, 2020).
78445	BI0061	1053	Crimean-Congo Haemorrhagic Fever (Human)	Crimean-Congo haemorrhagic fever (CCHF) is a tick-borne viral infection caused by the CCHF virus. It causes severe viral haemorrhagic fever outbreaks and epidemics (WHO, 2013).
78446	BI0062	1053	Ebola (Human)	Ebola virus disease (EVD) is a rare but severe zoonotic viral infectious disease caused by the Ebola virus. It can lead to haemorrhagic fever and is often fatal in humans. EVD can trigger epidemics with high casefatality rates (WHO, 2020).
78447	BI0063	1053	Lassa Fever (Human)	Lassa fever is a zoonotic disease associated with acute and potentially fatal haemorrhagic illness caused by Lassa virus. It is associated with epidemics particularly where it is endemic in Benin, Ghana, Guinea, Liberia, Mali, Sierra Leone, and Nigeria (WHO, 2017).
78448	BI0064	1053	Tuberculosis (Human and Animal)	Tuberculosis (TB) is a curable bacterial infectious disease caused by Mycobacterium tuberculosis that most commonly affects the lungs. It causes national epidemics of varied severity worldwide. Forms of TB that are resistant to treatment – multi-drug resistant TB (MDR-TB) and extensively drug-resistant TB (XDR-TB) – are public health crises and threaten health security worldwide (WHO, 2020).
78449	BI0065	1053	Middle East Respiratory Syndrome (MERS)	Middle East respiratory syndrome (MERS) is a viral respiratory disease caused by MERS-Corona Virus (MERS-CoV) (WHO, 2019).
78450	BI0066	1053	Monkeypox (Human)	Monkeypox is a viral zoonotic disease that has symptoms similar to those of smallpox (WHO, 2019).
78451	BI0067	1053	Rabies (Animal and Human)	Rabies is a vaccine preventable zoonotic disease causing acute encephalitis which can progress towards coma and death typically within 7 to 10 days of the first signs if no intensive care is instituted. It is a disease of public health concern (adapted from WHO, 2018, 2020).
78452	BI0068	1053	Severe Acute Respiratory Syndrome (SARS)	Severe acute respiratory syndrome (SARS) is a viral respiratory illness caused by a coronavirus called SARS-associated coronavirus (SARSCoV) (WHO, 2019).
78455	BI0072	1053	Brucellosis (Animal)	Brucellosis is a bacterial disease caused by various Brucella species, which mainly infect cattle, swine, goats, sheep and dogs (WHO, 2020).
78456	BI0074	1053	Contagious Bovine Pleuropneumonia (CBPP) (Animal)	Contagious bovine pleuropneumonia is an infectious and contagious respiratory disease of Bovidae caused by Mycoplasma mycoides subspecies mycoides SC (Mmm) (OIE, 2018).
78457	BI0075	1053	Contagious Caprine Pleuropneumonia (CCPP) (Animal)	Contagious caprine pleuropneumonia is a severe disease of goats caused by Mycoplasma capricolum subsp. capripneumonIae (Mccp). The acute form of the disease is characterised by unilateral serofibrinous pleuropneumonia with severe pleural fluid (OIE, 2018).
78458	BI0076	1053	Foot and Mouth Disease Virus (Animal)	Foot-and-mouth disease is caused by a virus of the family Picornaviridae, genus Aphthovirus. It is a highly contagious and economically important disease of cloven-hoofed domestic animals (cattle, buffaloes, pigs, sheep, goats) and wild animals (FAO, 2012; OIE, 2018).
78459	BI0077	1053	Lumpy Skin Disease (Animal)	Lumpy skin disease is a vector-borne pox disease of domestic cattle and Asian water buffalo and is characterised by the appearance of skin nodules on all body surface including the udder (FAO, 2017).
78460	BI0078	1053	New World Screwworm (NWS) (Animal)	New World screwworms are a type of blow fly larvae (maggots) that can infest livestock and other warm blooded animals, including people. They most often enter an animal through an open wound and feed on the animal’s living flesh. If not treated, infestations can be fatal (OIE, 2020).
78461	BI0079	1053	Newcastle Disease Virus (Animal)	Newcastle disease is an infectious disease of birds caused by Newcastle disease virus, of the Paramyxovirdae family. The disease is seen mainly in chickens, but many bird species and even reptiles and mammals are susceptible to infection (OIE, 2018).
78462	BI0080	1053	Peste Des Petits Ruminants (Animal)	Peste des petits ruminants is a highly contagious and devastating disease of goats and sheep. The causative agent, Peste des petits ruminants virus is a member of the genus Morbillivirus, Family Paramyxoviridae and Order Mononegavirales (adapted from FAO, 2020a; OiE, 2020).
78463	BI0081	1053	Q Fever	Q fever is a widespread zoonosis caused by the bacterium Coxiella burnetii. The respiratory tract is the most common route of infection, which occurs by inhalation of contaminated dust and spray shed from infected animals. Livestock, more specifically dairy goats and cows are considered as the major ‘source’ for human infections; dairy products from infected goats or cows are also an important source of infection (FAO, no date).
78464	BI0082	1053	Rift Valley Fever (Animal)	Rift Valley fever (RVF) is an acute haemorrhagic viral disease, affecting small and large ruminants and camels. RVF virus is a member of the Phlebovirus genus. The disease causes high mortality especially in new borne and mass abortions in pregnant animals. Humans become infected from contact with tissues/blood of infected animals including abortive material and through mosquito bites. Disease in humans presents as influenza like illness, haemorrhagic fever, encephalitis and occasionally death (adapted from FAO, 2003; WHO, 2018; OIE 2020).
78465	BI0083	1053	Trypanosomosis (Animal)	Animal trypanosomosis is a lethal parasitic disease caused by unicellular organisms named trypanosomes. The disease is cyclically transmitted by the bite of infected tsetse flies and it affects both humans ‘sleeping sickness’ and livestock ‘nagana’ (FAO, 2020).
78466	BI0084	1053	West Nile Fever (Human)	West Nile virus disease is a fatal neurological disease caused by a virus transmitted through the bites of infected mosquitoes. The virus is a member of the flavivirus genus and belongs to the Japanese encephalitis antigenic complex of the family Flaviviridae (WHO, 2017).
78467	BI0086	1053	Trypanosomiasis (Human)	Trypanosomiasis, human African (sleeping sickness) is caused by protozoan parasites belonging to the genus Trypanosoma transmitted by infected tsetse flies and is endemic in 36 sub-Saharan African countries. Without treatment, the disease is considered fatal, where there are tsetse flies that transmit the disease (WHO, 2020).
78468	BI0070	1054	African Swine Fever (Animal)	African swine fever is a devastating haemorrhagic viral disease of pigs, affecting domestic and wild pigs of all ages and both sexes (FAO, OiE, and EC, 2019).
78469	BI0073	1054	Classical Swine Fever (Animal)	Classical swine fever, also known as hog cholera, is a contagious viral disease of domestic and wild swine. It is caused by a virus of the genus Pestivirus of the family Flaviviridae (OiE, 2020).
78470	BI0085	1054	Rinderpest (Animal)	Rinderpest was a disease caused by paramyxovirus in the genus Morbillivirus. It was most commonly observed in domestic cattle and buffaloes. The last confirmed outbreak of rinderpest was in 2001 and the disease was declared to have been eradicated globally in 2011 by the Food and Agriculture Organization of the United Nations (FAO) and the World Organisation for Animal Health (OIE). Rinderpest was a highly contagious viral disease of animals that, throughout history, has resulted in the mortality of hundreds of millions of livestock and has caused significant disruption and damage to agricultural supply chains throughout the world. Rinderpest is the first animal disease eradicated worldwide. The last confirmed outbreak of rinderpest was in 2001. Rinderpest was declared as eradicated by 2011. The Rinderpest Secretariat (FAO and OIE joint activity) is engaged in safeguarding the global freedom, similar to what has been done for smallpox by the World Health Organization (OIE, 2019; FAO, 2020).
78471	BI0087	1055	Shrimp disease (bacterial) - Acute Hepatic	Shrimp acute hepatopancreatic necrosis disease (AHPND) is caused by virulent strains of Vibrio parahaemolyticus and related Vibrio species. AHPND-associated mortalities occur early in the production cycle, usually within 30 to 35 days of stocking, and because of this AHPND was initially referred to as early mortality syndrome (OIE, 2019).
78472	BI0088	1055	Oyster Disease Aquaculture	There are a number of causal agents recognised for oyster diseases. Examples of major oyster diseases and their causal protozoan agents are: bonamiosis (Bonamia exitiosa, B. ostreae); marteiliosis (Marteilia refringens); perkinsosis (Perkinsus marinus, P. olseni). These oyster diseases are notifiable OIE-listed diseases and occur worldwide (OIE, 2019).
78473	CH0001	1056	Ammonia	Ammonia (NH3) is a colourless acrid-smelling reactive gas at ambient temperature and pressure and is considered a significant public health hazard (WHO, 1986; PHE, 2019).
78474	CH0002	1056	Carbon Monoxide	Carbon monoxide is a colourless, odourless gas that can be poisonous to humans and is considered a significant public health hazard (WHO, 1999).
78490	CH0018	1061	Benzene	Benzene is a clear, colourless, highly flammable and volatile, liquid aromatic hydrocarbon (molecular formula C6H6) with a gasoline-like odour (WHO, 2019).
78596	MH0031	1075	Extra-tropical Cyclone	An extra-tropical cyclone is a low-pressure system which develops in latitudes outside the tropics (WMO, 1992).
78475	CH0015	1056	Phosphine	Phosphine (PH₃) is a colourless, flammable, and explosive gas at room temperature. The major uses of phosphine are as a rodenticide and fumigant for agricultural products and in the manufacture of semiconductors for the electronics industry. Exposure to low doses causes non-specific symptoms, such as nausea, vomiting, stomach pain, diarrhoea, thirst, muscle pain, difficulty breathing and fluid in the lungs. Exposure to higher doses may cause more severe effects, even death (adapted from PHE, 2017 and CDC, 2019).
78476	CH0016	1056	Chlorine	Chlorine is a reactive pale green gas with many uses including disinfection of water that is approximately three times heavier than air and has a characteristic odour similar to bleach. Most significant exposures to chlorine result from loss of containment of chlorine during storage and transport. Human exposure can result in symptoms ranging from mild irritation to rapid death related to pulmonary oedema. It is considered a significant public health hazard (adapted from IPCS, 1982 and PHE, 2019).
78477	CH0003	1057	Arsenic	Arsenic is a toxic heavy metal widely distributed throughout the Earth’s crust, generally as arsenic sulphide or as metal arsenates and arsenides. Human exposure to arsenic compounds represents a major public health concern as it has been associated with a range of acute and long-term adverse health effects and diseases (WHO, 2019).
78478	CH0004	1057	Cadmium	Cadmium is a toxic heavy metal which is widely distributed in the Earth’s crust (soil and rocks), air and water; however, human activity has greatly increased levels in environmental media relevant to population exposure. Human exposure to cadmium represents a major public health concern as it has been associated with a range of acute and long-term adverse health effects and diseases (WHO, 2019).
78479	CH0005	1057	Lead	Lead is a naturally occurring highly toxic heavy metal. Its widespread use has caused extensive environmental contamination and health problems in many parts of the world. It is a cumulative toxicant that affects multiple body systems, including the neurological, haematological, gastrointestinal, cardiovascular and renal systems. Children are particularly vulnerable to the neurotoxic effects of lead, and even relatively low levels of exposure can cause serious and, in some cases, irreversible neurological damage (WHO, 2010).
78480	CH0006	1057	Mercury	Mercury is a naturally occurring element that is found in air, water and soil. Exposure to mercury – even small amounts – may cause serious health problems and is a threat to the development of the foetus in utero and for children early in life (WHO, 2017).
78481	CH0007	1058	Levels of Contaminants in Food and Feed	A contaminant in food and feed is defined as any substance not intentionally added to food or feed for food-producing animals, which is present in such food or feed as a result of the production (including operations carried out in crop husbandry, animal husbandry and veterinary medicine), manufacture, processing, preparation, treatment, packing, packaging, transport or storage, or as a result of environmental contamination. Note: The term includes toxins, such as moulds, but does not include insect fragments, rodent hairs and other extraneous matter (FAO and WHO, 2019).
78482	CH0008	1059	Pesticides – Highly Hazardous	<p>Pesticide means any substance, or mixture of substances of chemical or biological ingredients intended for repelling, destroying or controlling any pest, or regulating plant growth. Pesticides are inherently toxic, and among them, a small number of Highly Hazardous Pesticides, cause disproportionate harm to the environment and human health. The Food and Agriculture Organization (FAO) and the World Health Organization (WHO) Guidelines on Highly Hazardous pesticides (UNEP, 2021) adopted the following definition:</p><p>“Highly Hazardous Pesticides means pesticides that are acknowledged to present particularly high levels of acute or chronic hazards to health or environment according to internationally accepted classification systems such as WHO or Global Harmonized System (GHS) or their listing in relevant binding international agreements or conventions. In addition, pesticides that appear to cause severe or irreversible harm to health or the environment under conditions of use in a country may be considered to be and treated as highly hazardous.”</p>
78483	CH0009	1059	Residue of Pesticides	Pesticide residue means any specified substance in food, agricultural commodities, or animal feed resulting from the use of a pesticide. The term includes any derivatives of a pesticide, such as conversion products, metabolites, reaction products, and impurities considered to be of toxicological significance (FAO and WHO, no date, 2019).
78484	CH0011	1059	Insecticides	Insecticides are chemicals used to control insects by killing them (CDC, 2019).
78485	CHO012	1059	Fungicides	Fungicides are chemicals that kill or slow the growth of fungi and their spores. They can be used on plants or other surfaces where mould or mildew grow (CDC, 2019).
78486	CH0010	1060	Hazardous Pesticide Contamination in Soils	Hazardous pesticide contamination in soils often results from improper storage of (obsolete) agrochemicals, as a result of which pesticides are spilled in the surroundings of the storage site, where they seep into the soil or are dispersed by wind. In some cases, pesticide spillage has been ongoing for many years. Such spillage may cause serious soil or groundwater contamination. In addition, highly toxic and persistent compounds have been used in agriculture for decades to control pests and diseases, which are proven to cause harm to non-target species. Although international agreements are put in place to regulate the production and use of those highly toxic and persistent compounds they will still remain in soils for several more decades. Moreover, in some countries, the international agreements are not yet being implemented or fully implemented, and therefore toxic pesticides are still being used. When soil and groundwater are contaminated, crops, livestock and drinking water may become affected and, when they are consumed by people, health risks may occur (FAO, 2000).
78487	CH0013	1060	Dioxins and Dioxin-like Substances	Dioxins and dioxin-like substances, including polychlorinated biphenyls (PCBs), polychlorinated dibenzo-p-dioxins (PCDDs) and polychlorinated dibenzofurans (PCDFs) are persistent organic pollutants (POPs) and are unwanted by-products of combustion and various industrial processes, such as chlorine bleaching of paper pulp and smelting. They can travel long distances from the source of emission, and bioaccumulate in food chains These substances represent a major public health concern. They have been associated with a range of acute and long-term adverse health effects and diseases (WHO, 2019).
78488	CH0014	1060	Microplastics	Microplastics are small plastic pieces less than five millimetres in length which can be harmful to the environment especially marine life. They originate from a variety of sources, including larger plastic debris that degrades into progressively smaller pieces (adapted from UNEP, 2016 and NOAA, no date).
78489	CH0017	1061	Oil Pollution	Oil pollution includes the accidental or deliberate, operational spills of oil from ships, especially tankers, offshore platforms and pipelines (Global Marine Oil Pollution Information Gateway, no date).
78491	CH0019	1062	Chemical Warfare Agents	Chemical agents or ‘chemical warfare agents’ (chemical weapons) are chemicals used to cause intentional death or harm through their toxic properties. Munitions, devices and other equipment specifically designed to weaponise toxic chemicals also fall under the definition of chemical weapons. The Chemical Weapons Convention (CWC) prohibition against the use of toxic chemicals and their precursors and also covers toxins of biological origin (OPCW, 2019a,b).
78492	CH0020	1063	Asbestos	Asbestos is the term for a group of naturally occurring minerals widely used historically in building materials and other products (WHO, no date). All types of asbestos cause lung cancer, mesothelioma, cancer of the larynx and ovary, and asbestosis (fibrosis of the lungs) (WHO, no date).
78493	CH0021	1063	Aflatoxins	Aflatoxins are mycotoxins – toxic compounds that are naturally produced by certain types of mould (fungi). Aflatoxins are among the most poisonous mycotoxins and are produced by certain moulds (Aspergillus flavus and A. parasiticus) that grow in soil, decaying vegetation, hay, and grains. Aflatoxins pose a serious health risk to humans and livestock (WHO, 2018a,b).
78494	CH0022	1063	Fluoride - Excess or inadequate intake	Fluoride is a naturally occurring mineral to which the public are often exposed via drinking-water. Depending on dose intake fluoride may have both beneficial effects (reducing the incidence of dental caries) or negative effects (causing tooth enamel and skeletal fluorosis following prolonged high exposure) (adapted from NCBI, 2020 and WHO, no date).
78495	CH0023	1063	Methanol	Methanol is a colourless fairly volatile liquid with a faintly sweet pungent odour similar to ethyl alcohol. Outbreaks of methanol poisoning arise from the consumption of adulterated counterfeit or informally produced spirit drinks (adapted from NCBI, 2020 and WHO, 2014).
78496	CH0024	1063	Substandard and Falsified Medical Products	Substandard and falsified medical products are defined as those that may cause harm to patients and fail to treat the diseases for which they were intended (WHO, 2018).
78497	CH0025	1064	Marine Toxins	Marine toxins (biotoxins) are naturally occurring chemicals, mostly caused by certain types of toxic algae, but also by bacteria. These toxins can accumulate in fish and shellfish and present a human health hazard (WHO, no date). When people consume such contaminated aquatic products, depending on the toxins, they can evoke a variety of gastrointestinal and neurological illnesses (paralytic shellfish poisoning, amnesic shellfish poisoning, diarrhoeic shellfish poisoning, neurotoxic shellfish poisoning, azaspiracid shellfish poisoning and ciguatera poisoning).
78498	EN0001	1065	Household Air Pollution	Household air pollution is one of the leading causes of disease and premature death and is associated with inefficient cooking practices using polluting stoves paired with solid fuels and kerosene (WHO, 2018).
78499	EN0002	1065	Air Pollution (Point Source)	A point source of air pollution is an identifiable stationary location or fixed facility from which air pollutants are released, which may be manmade or natural in origin (adapted from Kibble and Harrison, 2005 and Dunne et al., 2014).
78500	EN0003	1065	Ambient (Outdoor) Air Pollution	Ambient (outdoor) air pollution is a leading environmental risk factor affecting urban and rural populations around the world, resulting in an estimated 4.2 million premature deaths in 2016 (WHO, 2018).
78501	EN0004	1065	Land Degradation	<p>Land degradation means reduction or loss, in arid, semi-arid and dry subhumid areas, of the biological or economic productivity and complexity of rainfed cropland, irrigated cropland or range, pasture, forest and woodlands resulting from land uses or from a process or combination of processes, including processes arising from human activities and habitation patterns such as: soil erosion caused by wind and/or water; deterioration of the physical, chemical and biological or economic properties of soil; and long-term loss of natural vegetation (UNCCD, 1993).</p><p>Alternative Definition: Land degradation is the reduction in the capability of the land to produce benefits from a particular land use under a specified form of land management (FAO, 1999).</p><p>Alternative Definition: Land degradation is a negative trend in land condition, caused by direct or indirect human-induced processes including anthropogenic climate change, expressed as long-term reduction or loss of at least one of the following: biological productivity, ecological integrity or value to humans. [Note: This definition applies to forest and non-forest land. Changes in land condition resulting solely from natural processes (such as volcanic eruptions) are not considered to be land degradation. Reduction of biological productivity or ecological integrity or value to humans can constitute degradation, but any one of these changes need not necessarily be considered degradation.] (Olsson et al., 2019).</p>
78502	EN0005	1065	Soil Degradation	Soil degradation is defined as a change in soil health status resulting in a diminished capacity of the ecosystem to provide goods and services for its beneficiaries (FAO, 2020).
78503	EN0006	1065	Runoff / Nonpoint Source Pollution	Nonpoint sources of pollution refer to pollution sources that are diffused and without a single point of origin or not introduced into a receiving freshwater or maritime environment from a specific outlet. The pollutants are generally carried off the land by storm-water run-off. The commonly used categories for nonpoint sources are agriculture, forestry, urban areas, mining, construction, dams and channels, land disposal and saltwater intrusion (UN data, no date).
78504	EN0007	1065	Salinity	<p>Saline soils are those which have an electrical conductivity of the saturation soil extract of more than 4 dS/m at 25°C (Richards, 1954). This value is generally used worldwide although the terminology committee of the Soil Science Society of America has lowered the boundary between saline and non-saline soils to 2 dS/m in the saturation extract (FAO, 1988).</p><p>Note: dS/m = decisiemens per metre this is equivalent to the measurement of electrical conductivity of the salinity which can also be described as millimho per centimetre, hence 1 dS/m = 1 mmho/cm. Once the dS/m is known this can be converted to either mg/L or parts per million (ppm) (University of California, 2020).</p>
78505	EN0008	1065	Biodiversity Loss	Biodiversity loss refers to the reduction of any aspect of biological diversity (i.e., diversity at the genetic, species and ecosystem levels) in a particular area through death (including extinction), destruction or manual removal; it can refer to many scales, from global extinctions to population extinctions, resulting in decreased total diversity at the same scale (IPBES, no date).
78506	EN0010	1065	Forest Declines and Diebacks	Forest declines and diebacks are episodic events characterised by premature, progressive loss of tree and stand vigour and health over a given period without obvious evidence of a single clearly identifiable causal factor such as physical disturbance or attack by primary disease or insect (Ciesla and Donaubauer, 1994).
78595	MH0030	1075	Depression or Cyclone (Low Pressure Area)	A depression or cyclone is a region of the atmosphere in which the pressures are lower than those of the surrounding region at the same level (WMO, 1992).
78507	EN0011	1065	Forest Disturbances	Forest disturbance is the damage caused by any factor (biotic or abiotic) that adversely affects the vigour and productivity of the forest and which is not a direct result of human activities. It includes disturbance by insect pests, diseases, severe weather events and fires (FAO, 2018, 2020).
78508	EN0014	1065	Desertification	Desertification refers to land degradation in arid, semi-arid and dry subhumid areas resulting from various factors, including climatic variations and human activities (UNCCD, 2017).
78509	EN0015	1065	Loss of Mangroves	Mangroves and the destruction of mangrove habitat is caused by both human and natural causes. Human activities in the form of farming, aquaculture, urban development and natural stressors such as erosion and extreme weather have driven mangrove habitat loss. The hazard of loss of mangroves and their ecosystem services has devastating socioeconomic and environmental consequences for coastal communities, especially in those areas with low mangrove diversity and low mangrove area (adapted from Ellison et al., 1996; Polidoro et al., 2010; and Goldberg, 2020).
78510	EN0016	1065	Wetland Loss/Degradation	Wetland loss/degradation is a negative trend in wetland condition, caused by physical or direct/indirect human-induced processes expressed as long-term reduction or loss of at least one of the following: biological productivity, ecological role or value to humans (Craig et al., 1979; Olsson et al., 2019). Where wetlands are defined as areas of marsh, fen, peatland or water, whether natural or artificial, permanent or temporary, with water that is static or flowing, fresh, brackish or salt, including areas of marine water the depth of which at low tide does not exceed six metres (Ramsar Convention 1971: Article 1.1). Wetlands may incorporate riparian and coastal zones adjacent to the wetlands, and islands or bodies of marine water deeper than six metres at low tide lying within the wetlands (Ramsar Convention 1971: Article 2.1).
78511	EN0017	1065	Coral Bleaching	Corals are subject to ‘bleaching’ when the seawater temperature is too high: they lose the symbiotic algae that give coral its colour and part of its nutrients. Severe, prolonged or repeated bleaching can lead to the death of coral colonies (United Nations, 2017).
78512	EN0018	1065	Compressive Soils	Compressible soils include both compressive and collapsible soils. Compressive soils are soils that are prone to volumetric change when subject to mechanical loading (USDA, 1990:30). Collapsible soils are metastable in that they are prone to volumetric change (collapse) on wetting and loading (Rogers, 1995).
78513	EN0019	1065	Soil Erosion	Soil erosion is defined as the accelerated removal of topsoil from the land surface through water, wind and tillage (FAO, 2020).
78514	EN0020	1065	Coastal Erosion and Shoreline Change	Coastal erosion is the physical reduction of land mass at the coast that results from the interfacing of marine, fluvial and landsliding (driven by the interactions between groundwater and the soil or rock) processes with the coast (Mentaschi et al., 2018).
78515	EN0021	1065	Permafrost Loss	Permafrost is defined as the ground that remains frozen under 0°C for a minimum of two consecutive years. Permafrost loss, also known as permafrost thaw is the progressive loss of ground ice in permafrost, usually due to input of heat. Thaw can occur over decades to centuries over the entire depth of permafrost ground, with impacts occurring while thaw progresses. During thaw, temperature fluctuations are subdued because energy is transferred by phase change between ice and water. After the transition from permafrost to non-permafrost, ground can be described as thawed (IPCC, 2019).
78516	EN0022	1065	Sand Mining	Sand mining (extraction) is defined as the removal of primary (virgin) natural sand and sand resources (mineral sands and aggregates) from the natural environment (terrestrial, riverine, coastal, or marine) for extracting valuable minerals, metals, crushed stone, sand and gravel for subsequent processing (UNEP, 2019).
78517	EN0023	1065	Sea Level Rise	Sea-level change (sea-level rise / sea-level fall) is a change to the height of sea level, both globally and locally (relative sea-level change) at seasonal, annual, or longer time scales due to: a change in ocean volume as a result of a change in the mass of water in the ocean (e.g., due to melt of glaciers and ice sheets); to changes in ocean volume as a result of changes in ocean water density (e.g., expansion under warmer conditions), and to changes in the shape of the ocean basins and changes in the Earth’s gravitational and rotational fields, and local subsidence or uplift of the land (IPCC, 2019).
78518	EN0024	1065	Eutrophication	Eutrophication is the overabundance of nutrients in a body of water that results in harmful algal blooms, fish kills, and in some cases ecosystem collapse. It is a process driven by enrichment of water by nutrients, particularly compounds of nitrogen and/or phosphorus, leading to increased growth, primary production and biomass of algae; changes in the balance of nutrients causing changes to the balance of organisms; and water quality degradation (NOAA, 2007; UNEP, 2015).
78519	EN0009	1066	Deforestation	Deforestation is the conversion of forest to other land use independently of whether human-induced or not (FAO, 2020).
78520	EN0012	1066	Forest Invasive Species	Forest invasive species are any species that are non-native to a particular forest ecosystem and whose introduction and spread causes, or are likely to cause, socio-cultural, economic or environmental harm or harm to human health (adapted from FAO, 2015).
78521	EN0013	1066	Wildfires	Wildfires are any unplanned or uncontrolled fire affecting natural, cultural, industrial and residential landscapes (adapted from FAO, 2010).
78522	ET0001	1067	Airburst	An airburst is defined as an explosion in the air, especially of a nuclear bomb or large meteorite (Lexico Dictionary, no date).
78523	ET0002	1067	Geomagnetic Storm (including energetic particles related to space weather, and solar flare radio blackout [R Scale])	A geomagnetic storm is a worldwide disturbance of the Earth’s magnetic field induced by a solar storm (Cannon et al., 2013).
78524	ET0003	1067	UV Radiation	UV radiation is the portion of the electromagnetic (EM) spectrum between X-rays and visible light. Depending on its wavelength, UV radiation can penetrate the ozone layer and affect human health in different ways (Government of Canada, 2019).
78525	ET0004	1067	Meteorite Impact	A meteorite is an object that survives a trip through Earth’s atmosphere and hits the ground (adapted from NASA, no date).
78526	ET0005	1067	Ionospheric Storms	<p>An ionospheric storm is defined as turbulence in the F region of the ionosphere, usually due to a sudden burst of radiation from the Sun (WMO, 1992).</p><p>NB. The F region is the highest region of the ionosphere, at altitudes greater than 160 km (100 miles).</p>
78527	ET0006	1067	Radio Blackout	Radio blackout is a prolonged period of fading or faded radio communications, primarily in the high frequency range from ionospheric changes because of increased solar activity, in particular solar flares of C-class level or higher on the sunlit side of Earth (AMS, 2018).
78528	ET0007	1067	Solar Storm (Solar Radiation Storm) (S Scale)	Solar radiation storms occur when large quantities of charged particles, primarily protons, accelerated by eruptive processes at or near the Sun reach the near-Earth environment (NOAA, 2019).
78529	ET0008	1067	Space Hazard / Accident	A space accident is any accident involving space objects that causes damage (adapted from UNGA, 1971).
78530	ET0009	1067	Near-Earth Object	A near-Earth object (NEO) is an asteroid or comet whose trajectory brings it to within 1.3 astronomical units of the Sun and hence within 0.3 astronomical units, or approximately 45 million kilometres, of the Earth’s orbit (UN OOSA, no date).
78531	GH0001	1068	Earthquake	Earthquake is a term used to describe both sudden slip on a fault, and the resulting ground shaking and radiated seismic energy caused by the slip, or by volcanic or magmatic activity, or other sudden stress changes in the Earth (USGS, no date).
78532	GH0002	1068	Ground Shaking (Earthquake)	Earthquake ground shaking is the movement of the Earth’s surface produced by seismic waves that are generated when an earthquake occurs (adapted from USGS, no date).
78533	GH0003	1068	Liquefaction (Earthquake Trigger)	Soil liquefaction occurs when soil is transformed from a solid to a liquid state as a result of increased pore pressure and reduced effective stress. It is typically caused by rapid loading of the soil during earthquake shaking (AGI, 2017).
78534	GH0004	1068	Earthquake Surface Rupture, Fissures, and Tectonic Uplift/Subsidence	<p>Earthquake surface ruptures and fissures are localised ground displacements that develop during and immediately after an earthquake, where the fault which hosted the earthquake intersects the Earth’s surface. Surface ruptures represent the upward continuation of fault slip at depth, while fissures are smaller displacements, or more distributed deformation in and around the rupture area (adapted from USGS, no date and PNSN, no date).</p><p>Tectonic uplift and subsidence are the distributed vertical permanent ground deformations (warping) that result from displacement on a dipping (inclined) fault (Styron, 2019).</p>
78535	GH0005	1068	Subsidence and Uplift, Including Shoreline Change (Earthquake Trigger)	Tectonic uplift and subsidence are the distributed vertical permanent ground deformations (warping) that result from earthquake displacements on a dipping (inclined) fault (Styron, 2019). This includes changes to the shoreline as a result of uplift and subsidence.
78536	GH0006	1068	Tsunami (Earthquake Trigger)	Tsunami is the Japanese term meaning wave (‘nami’) in a harbour (‘tsu’). It is a series of travelling waves of extremely long length and period, usually generated by disturbances associated with earthquakes occurring below or near the ocean floor (IOC, 2019).
78537	GH0007	1068	Landslide or Debris Flow (Earthquake Trigger)	Landslide is the downslope movement of soil, rock and organic materials under the effects of gravity, which occurs when the gravitational driving forces exceed the frictional resistance of the material resisting on the slope. Landslides could be terrestrial or submarine (Varnes, 1978).
78538	GH0008	1068	Ground Gases (Seismogenic)	Ground gases generated in the ground from magma (molten or semimolten natural material derived from the melting of land or oceanic crust) include carbon dioxide, sulphur dioxide, hydrogen sulphide and hydrogen halides (adapted from IVHHN, 2020 and USGS, no date).
78539	GH0009	1069	Lava Flows (Lava Domes)	A lava flow or lava dome is a body of lava that forms during an eruption, or main eruptive episode. Lava flows are outpourings of fluid, relatively low-viscosity molten rock, whereas a lava dome is a pile of relatively viscous lava that cannot flow far from the vent (Calder et al., 2015; Kilburn, 2015).
78540	GH0010	1069	Ash/Tephra Fall (Physical and Chemical)	Tephra is a collective term for fragmented magma and old (i.e., preexisting) rocks ejected into the atmosphere from volcanic vents during an explosive eruption, irrespective of size, composition and shape (BGS, no date). The term ‘volcanic ash’ refers to the finest particles of tephra (less than 2 mm diameter).
78541	GH0011	1069	Ballistics (Volcanic)	Ballistics comprise fragments of magma and old (i.e., pre-existing) rocks ejected during an explosive eruption at variable velocity and angle on cannon ball-like trajectories; they are not entrained within the volcanic plume and are dispersed in proximity to the vent (typically <5 km) (adapted from Biass et al., 2016 and Bonadonna et al., 2021).
78542	GH0012	1069	Pyroclastic Density Current	Pyroclastic density currents are hot, fast-moving mixtures of volcanic particles and gas that flow according to their density relative to the surrounding medium and the Earth’s gravity. They typically originate from the gravitational collapse of explosive eruption columns, lava domes or lava-flow fronts, and from explosive lateral blasts (adapted from Branney and Kokelaar, 2002 and Cole et al., 2015).
78543	GH0013	1069	Debris Flow/Lahars/Floods	Lahars are discrete, rapid, gravity-driven, water-saturated flows containing water and solid particles of volcanic rock, sediment, ice, wood, and other debris that originate at volcanoes (Gudmundsson, 2015; Vallance and Iverson, 2015).
78544	GH0014	1069	Landslide (Volcanic Trigger)	A landslide is the downslope movement of soil, rock and organic materials under the effects of gravity, which occurs when the gravitational driving forces exceed the frictional resistance of the material resisting on the slope. Landslides could be terrestrial or submarine (Varnes, 1978).
78545	GH0015	1069	Ground Shaking (Volcanic Earthquake)	<p>Ground shaking is the movement of the Earth’s surface from earthquakes. Ground shaking is produced by waves that travel through the earth and along its surface (USGS, no date).</p><p>A volcanic earthquake is any earthquake that results from tectonic forces which occur in conjunction with volcanic activity (UN-SPIDER, no date).</p>
78546	GH0016	1069	Volcanic Gases and Aerosols	<p>Volcanic gas includes any gas-phase substance that is emitted by volcanic or volcanic-geothermal activity. Volcanic aerosols include liquid or solid particles that are small enough to be suspended in the air, and that are emitted by volcanic or volcanic-geothermal activity (adapted from Baxter and Horwell, 2015, Fischer and Chiodini 2015, and Williams- Jones and Rymer 2015).</p>
78547	GH0017	1069	Tsunami (Volcanic Trigger)	Volcano tsunamis (pronounced soo-ná-mees), are a series of waves created when water surrounding a volcano is displaced following an eruption, a landslide, or failure of a volcanic edifice into surrounding water. If the generating mechanism is large enough, the waves can be significant on local, regional or even transoceanic scales (Day, 2015).
78548	GH0018	1069	Lightning (Volcanic Trigger)	Volcanic lightning is an electrical discharge caused by a volcanic eruption. It is typically associated with ash-rich eruption plumes but can also arise from a range of volcanic processes including ground-hugging ash flows and lava-ocean entry (adapted from Mather and Harrison, 2006; Behnke and McNutt, 2014; and McNutt and Thomas, 2015).
78549	GH0019	1069	Urban Fire (During/Following Volcanic Eruption)	Urban fires are fire involving buildings or structures in cities or towns with potential to spread to adjoining structures. Triggers of urban fires are numerous, from human actions (e.g., knocking over a candle) and technological triggers (e.g., power surge overloading appliances), to natural triggers (e.g., wildland fires interacting with urban areas). Triggers from volcanic eruptions include lava flows, pyroclastic density currents, tephra, and ground shaking (adapted from Baxter et al., 2005 and ISO, 2020).
78550	GH0020	1069	Subsidence and Uplift, Including Shoreline Change (Magmatic/Volcanic Trigger)	Volcanic uplift and subsidence are deformations of the ground associated with volcanic unrest and eruptions (Dzurisin, 2007).
78551	GH0021	1070	Ground Shaking (induced earthquake, reservoir fill, dams, cavity collapse, underground explosion, impact, hydrocarbon fields, shale exploration, etc.)	Induced seismic ground shaking comprises non-tectonic (i.e., nonnatural) earthquakes which result from human activities that alter the stresses and strains on the Earth’s crust. Most induced seismicity is of a low magnitude and higher frequency than larger magnitude events with longer wavelengths and lower frequencies (USGS, 2016).
78552	GH0022	1070	Liquefaction (Groundwater Trigger)	Liquefaction is the term applied to the loss of strength experienced in loosely packed, saturated or close to saturated sediments at or near the ground surface in response to strong ground shaking, such as earthquakes, cyclic loading, and vibration from machinery, or due to the development of excess pore pressure resulting from a change in head or confining pressures. The loss of strength causes the soil to behave like a viscous fluid, sometimes referred to as ‘running sand’, until the excess pore pressure returns to hydrostatic (USGS, no date).
78553	GH0023	1070	Ground Fissuring	Ground fissures form in response to tensional stresses, most commonly in unconsolidated sediment, but also in rock (Arizona Geological Survey, 2020).
78554	GH0024	1070	Subsidence and Uplift Including Shoreline Change	Subsidence is a lowering or collapse of the ground (BGS, 2020). Uplift is the converse.
78555	GH0025	1070	Shrink-Swell Subsidence	Subsidence is a lowering or collapse of the ground, caused by various factors, including groundwater lowering, sub-surface mining or tunnelling, consolidation, sinkholes, or changes in moisture content in expansive soils. Shrink-swell is the term applied to the behaviour of expansive soils, which are a group of soils that exhibit volumetric change in response to changes in moisture content, such that they shrink in response to desiccation and swell by hydration, resulting in ground subsidence and ground heave respectively (BGS, 2020).
78556	GH0026	1070	Sinkhole	A sinkhole is a closed depression in karst (a landscape resulting from the dissolution of soluble rock) by current or palaeo internal drainage, also known as a doline. This is one of several hazards that result in subsidence, i.e., lowering or collapse of the ground (adapted from USGS, no date; and BGS, no date).
78557	GH0027	1070	Ground Gases (CH4, Rn, etc.)	Ground gases that result from material decay (natural or anthropogenic) typically include radon, methane, carbon dioxide, hydrogen sulphide, but may also include the break down products of other compounds, such as nitrogen, alcohols, alkanes, cycloalkanes and alkenes, aromatic hydrocarbons (monocyclic or polycyclic); esters and ethers, as well as halogenated compounds and organosulphur. Ground gases derived from magma (molten or semi-molten natural material derived from the melting of land or oceanic crust) include carbon dioxide, sulphur dioxide, hydrogen sulphide and hydrogen halides. Ground gases are gases released in combination with water vapour and particulate matter during volcanogenic events, or via fumaroles, and hydrothermal systems (adapted from NHBC (UK), 2007; IVHHN, 2020; US EPA, no date; and USGS, no date).
78558	GH0028	1070	Riverbank Erosion	Riverbank erosion is the removal of material from the banks of rivers when flowing water forces exceed bank resisting forces by the soil and vegetation, for example, when river levels are sufficiently high, primarily due to fluvial energy and atmospheric processes and secondarily because of the resultant geotechnical instability and consequential riverbank failure. Riverbank failure can also occur as a consequence of Earth hazards, such as volcanos and earthquakes (USDA, no date).
78559	GH0029	1070	Sand Encroachment	Sand encroachment occurs generally in arid to semi-arid regions when grains of sand are carried by winds and form sandy accumulation on coasts, along water courses and on cultivated or uncultivated land. As the accumulations of sand (dunes) move, they bury towns, roads, oases, crops, market gardens, irrigation channels and dams, thus causing major material and socioeconomic damage (FAO, 2010).
78560	GH0030	1070	Aquifer Recharge (Systems Failure/Outages)	An aquifer is a water-bearing rock that readily transmits water to wells and springs. It can be recharged either naturally (precipitation including rainfall or snow) or artificially (e.g., pumped river recharge via wells). Failure or outage can be due to derogation, well failure or contamination (USGS, no date).
78561	GH0031	1070	Submarine Landslide	A submarine landslide is a downslope movement of sediment or rock under the effect of gravity, which occurs when the stresses acting downslope exceed the available strength of the sediment on the slope (Lee et al., 2007).
78562	GH0032	1070	Rockfall	Rockfall is a fragment of rock (a block) detached by sliding, toppling, or falling, that falls along a vertical or sub-vertical cliff, and proceeds down slope by bouncing and flying along ballistic trajectories or by rolling on talus or debris slopes (Highland and Bobrowsky, 2008).
78563	GH0033	1070	Landscape Creep	Landscape creep is the imperceptibly slow, steady, downward movement of slope-forming soil or rock. Movement is caused by shear stress, sufficient to produce permanent deformation, but too small to produce shear failure (adapted from Hutchinson, 1968; and Varnes, 1978).
78564	GH0034	1070	Sediment Rock Avalanche	Rock avalanches are a translational form of mass movement where the transported material is dry rock that is fragmented before or during slope failure. They are rapid with long runouts and large volumes and often involve the entrainment of slope material, commonly therefore, giving rise to debris slides or flows. The motion of rock avalanches is massive such that the bulk of the rock fragments move together as a largely coherent mass (adapted from Collins, 2014 and USGS, no date).
78565	GH0035	1070	Tsunami (Submarine Landslide Trigger)	Tsunami is a Japanese term meaning wave (‘nami’) in a harbour (‘tsu’). It is a series of travelling waves of extremely long length and period. They are usually generated by seabed disturbances associated with earthquakes occurring below or near the ocean floor, but also by other mechanisms such as submarine landslides (IOC, 2019).
78566	MH0001	1071	Downburst	A downburst is a violent and damaging downdraught reaching the ground surface, associated with a severe thunderstorm (WMO, 1992).
78567	MH0002	1071	Lightning (Electrical Storm)	Lightning is the luminous manifestation accompanying a sudden electrical discharge which takes place from or inside a cloud or, less often, from high structures on the ground or from mountains (WMO, 2017).
78568	MH0003	1071	Thunderstorm	A thunderstorm is defined as one or more sudden electrical discharges, manifested by a flash of light (lightning) and a sharp or rumbling sound (thunder) (WMO, no date).
78569	MH0004	1072	Coastal Flood	Coastal flooding is most frequently the result of storm surges and high winds coinciding with high tides. The surge itself is the result of the raising of sea levels due to low atmospheric pressure. In particular configurations, such as major estuaries or confined sea areas, the piling up of water is amplified by a combination of the shallowing of the seabed and retarding of return flow (WMO, 2011).
78570	MH0005	1072	Estuarine (Coastal) Flood	Estuarine flooding is flooding over and near coastal areas caused by storm surges and high winds coincident with high tides, thereby obstructing the seaward river flow. Estuarine flooding can be caused by tsunamis in specific cases (WMO, 2011).
78571	MH0006	1072	Flash Flood	A flash flood is a flood of short duration with a relatively high peak discharge in which the time interval between the observable causative event and the flood is less than four to six hours (WMO, 2006).
78572	MH0007	1072	Fluvial (Riverine) Flood	A fluvial flood is a rise, usually brief, in the water level of a stream or water body to a peak from which the water level recedes at a slower rate (WMO, 2012).
78573	MH0008	1072	Groundwater Flood	A groundwater flood is the emergence of groundwater at the ground surface away from perennial river channels or the rising of groundwater into man-made ground, under conditions where the ‘normal’ ranges of groundwater level and groundwater flow are exceeded (BGS, 2010).
78574	MH0009	1072	Ice-Jam Flood Including Debris	<p>An ice jam flood including debris is defined as an accumulation of shuga including ice cakes, below ice cover. It is broken ice in a river which causes a narrowing of the river channel, a rise in water level and local floods (WMO, 2012).</p><p>Shuga is defined as accumulation of spongy white ice lumps, a few centimetres across, formed from grease ice or slush, and sometimes from anchor ice rising to the surface (WMO, 2012).</p>
78575	MH0010	1072	Ponding (Drainage) Flood	A ponding flood is a flood which results from rainwater ponding at or near the point where it falls because it is falling faster than the drainage system (natural or man-made) can carry it away (WMO, 2006).
78576	MH0011	1072	Snowmelt Flood	A snowmelt flood is a significant flood rise in a river caused by the melting of snowpack accumulated during the winter (WMO, 2012).
78577	MH0012	1072	Surface Water Flooding	Surface water flooding is that part of the rain which remains on the ground surface during rain and either runs off or infiltrates after the rain ends, not including depression storage (WMO, 2012).
78578	MH0013	1072	Glacial Lake Outburst Flood	A ‘glacial lake outburst flood’ is a phrase used to describe a sudden release of a significant amount of water retained in a glacial lake, irrespective of the cause (Emmer, 2017).
78579	MH0014	1073	Black Carbon (Brown Clouds)	Black carbon refers to the absorbing components of soot, often defined using elemental carbon and some condensed organics. Black carbon is an important part of the combustion product commonly referred to as soot. Black carbon in indoor environments is largely due to cooking with biofuels such as wood, dung and crop residue. Outdoors, it is due to fossil fuel combustion (diesel and coal), open biomass burning (associated with deforestation and crop residue burning), and cooking with biofuels (Ramanathan and Carmichael, 2008).
78580	MH0015	1073	Dust storm or Sandstorm	A dust storm is an ensemble of particles of dust or sand energetically lifted to great heights by a strong and turbulent wind (WMO, 2017).
78581	MH0016	1073	Fog	Fog is a suspension of very small, usually microscopic water droplets in the air, reducing visibility at the Earth’s surface (WMO, 2017).
78582	MH0017	1073	Haze	Haze is a suspension in the air of extremely small, dry particles invisible to the naked eye and sufficiently numerous to give the air an opalescent appearance (WMO, 2017).
78583	MH0018	1073	Polluted Air	<p>Polluted air is air containing dust, smoke, micro-organisms or gases different from those from which it would normally be composed (WMO, 1992).</p><p>Alternative definition: Polluted air is air which contains gases and particles emitted to the atmosphere by a variety of human activities and natural sources, or formed in the atmosphere, that at critical levels have harmful effects on human health, animals, plants and ecosystems, or reduce visibility and corrode materials, buildings and cultural heritage sites (UNEP, no date).</p>
78584	MH0019	1073	Sand haze	Sand haze is haze caused by the suspension in the atmosphere of small sand or dust particles, raised from the ground prior to the time of observation by a sandstorm or dust storm (WMO, 1992).
78585	MH0020	1073	Smoke	Smoke is a suspension in the air of small particles produced by combustion (WMO, 2017).
78586	MH0021	1074	Ocean Acidification	Ocean acidification refers to a reduction in the pH of the ocean over an extended period, which is caused primarily by uptake of carbon dioxide from the atmosphere and can also be caused by other chemical additions or subtractions from the ocean (IPCC, 2011).
78587	MH0022	1074	Rogue Wave	Rogue waves are extreme waves with overall or crest heights that are abnormally high relative to the background significant wave height (WMO, 2018).
78588	MH0023	1074	Sea Water Intrusion	Seawater intrusion is the process by which saltwater infiltrates a coastal aquifer, leading to contamination of fresh groundwater (NRC, 2011).
78589	MH0024	1074	Sea Ice (Ice Bergs)	Sea ice is any form of ice found at sea (WMO, 2015).
78590	MH0025	1074	Ice Flow	Ice flow is the motion of ice driven by gravitational forces, ice stress or, for sea ice, wind, water currents and tide (AMS, 2012).
78591	MH0026	1074	Seiche	Seiches are sea-level oscillations at the resonant frequency of enclosed bodies of water (WMO, 2011).
78592	MH0027	1074	Storm Surge	A storm surge reflects the difference between the actual water level under the influence of a meteorological disturbance (storm tide) and the level which would have occurred in the absence of the meteorological disturbance (i.e., astronomical tide) (WMO, 2008, 2011, 2017).
78593	MH0028	1074	Storm Tides	A storm tides is the actual sea level as influenced by a weather disturbance. The storm tide consists of the normal astronomical tide plus the storm surge (WMO, 2017).
78594	MH0029	1074	Tsunami	Tsunami is the Japanese term meaning wave (‘nami’) in a harbour (‘tsu’). It is a series of travelling waves of extremely long length and period, usually generated by disturbances associated with earthquakes occurring below or near the ocean floor (IOC, 2019).
78597	MH0032	1075	Sub-Tropical Cyclone	A sub-tropical cyclone is a non-frontal low-pressure system that has characteristics of both tropical and extratropical cyclones. Like tropical cyclones, they are non-frontal, synoptic-scale cyclones that originate over tropical or subtropical waters and have a closed surface wind circulation about a welldefined centre (WMO, 2017).
78598	MH0033	1076	Acid Rain	Acid rain is rain which in the course of its history has combined with chemical elements or pollutants in the atmosphere and reaches the Earth’s surface as a weak acid solution (WMO/UNESCO, 2012).
78599	MH0034	1076	Blizzard	A blizzard is a severe snow storm characterised by poor visibility, usually occurring at high-latitude and in mountainous regions (WMO, 1992).
78600	MH0035	1076	Drought	A drought is a period of abnormally dry weather characterised by a prolonged deficiency of precipitation below a certain threshold over a large area and a period longer than a month (WMO, 2020).
78601	MH0036	1076	Hail	Hail is precipitation in the form of particles of ice (hailstones). These can be either transparent, or partly or completely opaque. They are usually spheroidal, conical or irregular in form, and generally 5−50 mm in diameter. The particles may fall from a cloud either separately or agglomerated in irregular lumps (WMO, 2017).
78602	MH0037	1076	Ice Storm	An ice storm involves the intense formation of ice on objects by the freezing, on impact, of rain or drizzle (WMO, 1992).
78603	MH0038	1076	Snow	Snow is the precipitation of ice crystals, isolated or agglomerated, falling from a cloud (WMO, 2017).
78604	MH0039	1076	Snow Storm	A snow storm is a meteorological disturbance giving rise to a heavy fall of snow, often accompanied by strong winds (WMO, 1992).
78605	MH0040	1077	Cold Wave	A cold wave is a period of marked and unusual cold weather characterised by a sharp and significant drop in air temperatures near the surface (maximum, minimum and daily average) over a large area and persisting below certain thresholds for at least two consecutive days during the cold season (WMO, 2020).
78606	MH0041	1077	Dzud	A dzud (a Mongolian term that describes ‘severe winter conditions’’, sometimes spelled zud) is a cold-season disaster in which anomalous climatic (i.e., heavy snow and severe cold) and/or land-surface (snow/ ice cover and lack of pasture) conditions lead to reduced accessibility and/or availability of forage/pastures, and ultimately to high livestock mortality during winter–spring. Severe dzuds (high mortality) result from a combination of growing-season drought and severe weather (Natsagdorj and Dulamsuren, 2001; Nandintsetseg et al., 2017, 2018a,b).
78607	MH0042	1077	Freeze	A freeze is an air temperature equal to or less than the freezing point of water (D °C) (adapted from WMO, 1992).
78608	MH0043	1077	Frost (Hoar Frost)	A hoar frost is a deposit of ice produced by the deposition of water vapour from the surrounding air and is generally crystalline in appearance (WMO, 2017).
78609	MH0044	1077	Freezing Rain (Supercooled Rain)	Freezing rain is rain where the temperature of the water droplets is below 0°C. Drops of supercooled rain may freeze on impact with the ground, in-flight aircraft or other objects (WMO, 2017).
78610	MH0045	1077	Glaze	Glaze is a smooth compact deposit of ice, generally transparent, formed by the freezing of super-cooled drizzle droplets or raindrops on objects with a surface temperature below or slightly above 0°C (WMO, 2017).
78611	MH0046	1077	Ground Frost	Ground frost is a covering of ice, in one of its many forms, produced by the sublimation of the water vapour on objects colder than 0°C (WMO, 1992). Ground frost occurs when the temperature of the upper layer of the soil is less than 0°C (WMO, 1992).
78612	MH0047	1077	Heatwave	A heatwave is a marked warming of the air, or the invasion of very warm air, over a large area; it usually lasts from a few days to a few weeks (WMO, 1992). Alternative definition: A heatwave is a marked unusual period of hot weather over a region persisting for at least two consecutive days during the hot period of the year based on local climatological conditions, with thermal conditions recorded above given thresholds (WMO, 2020).
78613	MH0048	1077	Icing (Including Ice)	Icing refers to any deposit or coating of ice on an object caused by the impact of liquid hydrometeors, usually supercooled (WMO, 1992).
78614	MH0049	1077	Thaw	Thaw is the melting of snow or ice at the Earth’s surface due to a temperature rise above 0°C (WMO, 1992).
78615	MH0050	1078	Avalanche	An avalanche is a mass of snow and ice falling suddenly down a mountain slope and often taking with it earth, rocks and rubble of every description (WMO, 1992).
78616	MH0051	1078	Mud Flow	A mud flow is a flow of water so heavily charged with sediment and debris that the flowing mass is thick and viscous (WMO and UNESCO, 2012).
78617	MH0052	1078	Rock slide	A rock slide is a movement of a mass of soil or rock on an individualized failure surface (Dennis and Didier, 2019).
78618	MH0053	1079	Derecho	Derechos are fast-moving bands of thunderstorms with destructive winds. The winds can be as strong as those found in hurricanes or even tornadoes. Unlike hurricanes and tornadoes, these winds follow straight lines (NOAA, 2019).
78619	MH0054	1079	Gale (Strong Gale)	A gale is wind with a speed of between 34 and 40 knots (62–74 km/h, 32–38 mph). Also known as Beaufort scale wind force 8 (WMO, 1992).
78620	MH0055	1079	Squall	A squall is an atmospheric phenomenon characterised by a very large variation of wind speed: it begins suddenly, has a duration of the order of minutes and decreases suddenly in speed. It is often accompanied by a shower or thunderstorm (WMO, 2018).
78621	MH0056	1079	Subtropical Storm	A subtropical storm is a subtropical cyclone in which the maximum sustained surface wind speed (using the U.S. 1-minute average) is 34 kt (39 mph or 63 km/hr) or more (NOAA, 2019).
78622	MH0057	1079	Tropical Cyclone (Cyclonic Wind, Rain [Storm] Surge)	<p>A tropical cyclone is a cyclone of tropical origin of small diameter (some hundreds of kilometres) with a minimum surface pressure in some cases of less than 900 hPa, very violent winds and torrential rain; sometimes accompanied by thunderstorms. It usually contains a central region, known as the ‘eye’ of the storm, with a diameter of the order of some tens of kilometres, and with light winds and a more or less lightly clouded sky (WMO, 2017).</p><p>Alternative definition: A tropical cyclone is a warm-core, non-frontal synoptic-scale cyclone, originating over tropical or subtropical waters, with organised deep convection and closed surface wind circulation about a well-defined centre (WMO, 2017).</p>
78641	TL0007	1086	Structural Failure	Structural failure corresponds to the exceedance of ultimate limit state in many of the load-carrying elements, which compromise the structural stability of the building (Rossetto, 2013).
78623	MH0058	1079	Tropical Storm	<p>A tropical storm is a rapid rotating storm originating over tropical oceans. It has a low pressure centre and clouds spiralling towards the eyewall surrounding the ‘eye’. Its diameter is typically around 200 to 500 km, but can reach 1000 km. The related hazards are very violent winds, torrential rain, high waves, storm surges and in some cases tornadoes, causing direct effects such as flash floods, flooding, coastal inundation, and indirect effects such as landslides and mudslides. The winds blow anti-clockwise in the Northern Hemisphere and clockwise in the Southern Hemisphere (WMO, 2020).</p><p>The intensity of tropical storms is based on the wind speed. A tropical storm is a tropical cyclone with the maximum sustained winds of 34 knots (17.5 m/s, 63 km/h) to 47 knots (24.2 m/s, 87 km/h) near the centre. When reaching this intensity, they are named in the interests of public safety (WMO, 2021).</p>
78624	MH0059	1079	Tornado	A tornado is a rotating column of air, extending from the base of a cumuliform cloud, and often visible as a condensation funnel in contact with the ground, and/or attendant circulating dust or debris cloud at the ground (WMO, 2017).
78625	MH0060	1079	Wind	Wind is air motion relative to the Earth’s surface. Unless otherwise specified, only the horizontal component is considered (WMO, 1992).
78626	SO0001	1080	International Armed Conflict (IAC)	International armed conflict covers all cases of declared war and other de facto armed conflict between two or more States, even if the state of war is not recognised by one of them and/or the use of armed force is unilateral (ICRC, 2016).
78627	SO0002	1080	Non-International Armed Conflict (NIAC)	Non-international armed conflict is defined as protracted armed confrontations occurring between governmental armed forces and the forces of one or more armed groups, or between such groups arising on the territory of a State. The armed confrontation must reach a minimum level of intensity, and the parties involved in the conflict must show a minimum of organisation (ICRC, 2008).
78628	SO0003	1080	Civil Unrest	<p>‘Civil unrest’ is an umbrella term for a wide spectrum of phenomena, and although there is no commonly agreed United Nations definition the term is used widely among United Nations agencies, funds and programmes, particularly to describe violent and non-violent group acts.</p><p>A suggested definition for ‘civil unrest’ is as follows: a term that includes limited political violence (such as acts of ‘terrorism’, individual assassinations, etc.), sporadic violent collective action (such as riots), or nonviolent and mildly violent collective action (such as protests, demonstrations, etc.) – all of which tend to take place in times of peace (Kalyvas, 2000:3).</p>
78629	SO0004	1081	Explosive Remnants of War	Explosive remnants of war are unexploded ordnance and abandoned explosive ordnance that are left by a party to an armed conflict following the cessation of warfare. Explosive ordnance is defined as conventional munitions containing explosives (United Nations, 2004:2).
78630	SO0005	1081	Environmental Degradation from Conflict	Environmental degradation from conflict is defined as the reduction of the capacity of the environment to meet social and ecological objectives and needs (UNISDR, 2009:6).
78631	SO0006	1082	Violence	Violence refers to the intentional or unintentional use of force whether physical or psychological, threatened or actual, against an individual, oneself, or against a group of people, a community, or a government. Violence can either be targeted or indiscriminate, motivated by certain aims, including political, religious, social, economic, ethnic, racial, or gender-based, or unintentional and can be initiated with the aim to directly or indirectly inflict harm, injury or death (Krug et al., 2002). Armed as well as non-armed forms of violence can occur both in conflict and non-conflict settings. Violence has been explicitly identified as a significant public health problem (Rutherford et al., 2007).
78632	SO0007	1082	Stampede or Crushing (Human)	Stampede or crushing is the surge of individuals in a crowd, in response to a perceived danger or loss of physical space. It often disrupts the orderly movement of crowds resulting in irrational and dangerous movement for self-protection leading to injuries and fatalities (Illiyas et al., 2013).
78633	SO0008	1083	Financial shock	A financial shock is an unexpected disturbance which originates from the financial sector and has a significant effect on an economy (e.g. national, regional, or global). The term is largely used to refer to events which have negative impacts (ECB, 2013).
78634	TL0001	1084	Radioactive Waste	<p>Radioactive waste is radioactive material for which no further use is foreseen but still contains, or is contaminated with, radionuclides. Radioactive waste can be in gas, liquid or solid form (IAEA, 2018). It may remain radioactive from a few hours to hundreds of thousands of years.</p><p>N.B. For regulatory purposes radioactive waste is defined as material with activity concentrations greater than the clearance levels set by the regulatory authority (IAEA 2018).</p>
78635	TL0002	1084	Radioactive Material	A substance or a material emitting, or related to the emission of, ionising radiation (either in the form of electromagnetic waves or particle radiation) is radioactive (IAEA, 2018).
78636	TL0003	1085	Radiation Agents	A substance or a material emitting, or related to the emission of, ionizing radiation (either in the form of electro-magnetic waves or particle radiation) is radioactive. Depending on the magnitude of exposure, the radioactive substance may become a hazard to human health; as such it is subject to regulatory control by national laws and national regulatory authorities. Radioactive material may also be hazard to animal health, other forms of life and the environment (IAEA, 2018).
78637	TL0004	1085	Nuclear agents	Nuclear agents are derived from neutron radiation (n) which is a neutron emitted by an unstable nucleus, in particular during atomic fission and nuclear fusion. Apart from a component in cosmic rays, neutrons are usually produced artificially. Because they are electrically neutral particles, neutrons can be very penetrating and when they interact with matter or tissue, they cause the emission of beta- and gamma-radiation. Neutron radiation therefore requires heavy shielding to reduce exposure (IAEA, 2004).
78638	TL0053	1085	Explosive agents	Explosive agents include improvised explosive devices (IEDs) which can be made anywhere from a wide range of materials – from everyday tools, to conventional explosives, to commercial explosives used in construction and mining. They are cheap and relatively easy to construct (UNODA, 2014).
78639	TL0005	1086	Building Collapse	Building collapse is the failure of load-bearing structural elements, causing a building to fall or fail catastrophically / catastrophic failure (adapted from US Department of Labor, no date).
78640	TL0006	1086	Building, highrise, cladding	A building high-rise cladding fire hazard occurs when combustible materials such as cladding on a high-rise building greatly increases risk in the event of a fire and can have a catastrophic outcome (adapted from Rockpanel, no date)
78642	TL0008	1086	Bridge Failure	Bridge failure is the inability of a bridge, or its components, to perform as specified by its design and construction requirements (Wardhana and Hadipriono, 2003). Note: This definition includes bridges that have totally collapsed, partially collapsed and those that experienced distress, such as, exhibiting excessive deformation.
78643	TL0009	1086	Dam Failure	Dam failure is the collapse or movement of part of a dam or its foundation, such that the dam cannot retain water. In general, a failure results in a release of large quantities of water imposing risks on the people or property downstream (ICOLD, 2015).
78644	TL0010	1086	Supply Chain Failure	Supply chain failure refers to an event in the supply chain that disrupts the flow of materials on their journey from initial suppliers through to final customers (Walters, 2007).
78645	TL0011	1086	Critical Infrastructure Failure	Critical Infrastructure failure is defined as the failure in one or more of the physical structures, facilities, networks and other assets which provide services that are essential to the social and economic functioning of a community or society (UNGA, 2016).
78646	TL0012	1087	Nuclear Plant Failure	Nuclear plant failure occurs when the accidental melting of the core of a nuclear reactor results in either the core to have a complete or partial collapse (adapted from USNRC, 1975).
78647	TL0013	1087	Power Outage/ or Blackout	In the electric power domain, especially in power transmission and distribution, a power outage usually refers to a partial or total loss of power supply to some end user (e.g., population, enterprises, critical systems). Triggering factors may include accidents, equipment breakdowns, failure of control mechanisms, targeted attacks (physical or cyber), organisational errors, and natural hazards (adapted from Pescaroli et al., 2017; UK Cabinet Office, 2017; EIS Council, 2019; and FEMA, 2018).
78648	TL0014	1087	Emergency Telecommunications Failure	Emergency telecommunications failure is an umbrella term for telecommunications of an ‘extraordinary nature’ under abnormal and potentially adverse network conditions (ITU, 2007).
78649	TL0015	1087	Water Supply Failure	<p>Water supply failure is the physical shortage or scarcity in access of water supply due to the failure of institutions to ensure a regular supply or due to a lack of adequate infrastructure (adapted from UN-Water, no date).</p><p>Alternative definition: Water supply systems are networks whose edges and nodes are pressure pipes and either pipe junctions, water sources or end-users. Water supply systems are designed to protect the customer from natural biological contamination, and the same systems have potential efficacy against deliberate biological and chemical contamination (adapted from Franchin and Cavalieri, 2013; and Jain et al., 2014).</p>
78650	TL0016	1087	Radio and Other Telecommunication Failures	Radio and other telecommunication failures can be said to occur when there is internal or external interruption of communications by either party that results in difficult to transport the message as it was intended (adapted from Dainty et al., 2007).
78651	TL0017	1088	Misconfiguration of Software and Hardware	Misconfiguration of software and hardware is the incorrect or suboptimal configuration of an information system or system component that may lead to vulnerabilities (NIST, no date).
78652	TL0018	1088	Non-Conformity and Interoperability	<p>Conformity assessment: activity that provides demonstration that specified requirements relating to a product, process, system, person or body are fulfilled (NIST Information Technology Laboratory, no date).</p><p>For the purposes of this standard, interoperability allows any government facility or information system, regardless of the personal Identity verification (PIV) Issuer, to verify a cardholder’s identity using the credentials on the PIV Card (NIST, no date).</p>
78653	TL0019	1088	Malware	Malware is a summary term for different forms of malevolent software designed to infiltrate and infect computers, typically without the knowledge of the owner (ITU, 2008).
78654	TL0020	1088	Data Breach	A data breach is a compromise of security that leads to the accidental or unlawful destruction, loss, alteration, unauthorised disclosure of, or access to protected data transmitted, stored, or otherwise processed (ICO, no date).
78655	TL0021	1088	Data Security-Related Hazards	Data security is related to the preservation of data to guarantee availability, confidentiality and data integrity. Data security-related hazards include risks arising from increased system complexity because this provides opportunities for malicious cyberattacks and data loss in the case of serious incidents, including natural disasters (ITU, 2017).
78656	TL0023	1088	Outage	A cyber outage is the unavailability of a service or resource (ITU, 1996).
78657	TL0024	1088	Personally Identifiable Information (PII) Breach	A personally identifiable information (PII) breach is a situation where PII is processed in violation of one or more relevant PII protection requirements (ITU, 2018).
78658	TL0025	1088	Internet of Things (IOT)-Related Hazards	<p>The Internet of Things (IoT) is a global infrastructure for the information society, enabling advanced services by interconnecting (physical and virtual) things based on existing and evolving interoperable information and communication technologies (ITU, 2012).</p><p>NOTE 1: Through the exploitation of identification, data capture, processing and communication capabilities, the IoT makes full use of things to offer services to all types of applications, while ensuring that security and privacy requirements are fulfilled.</p><p>NOTE 2: From a broader perspective, the IoT can be perceived as a vision with technological and societal implications.</p><p>The IoT is a relatively new technology that is a hazard if a data security or breach occurs.</p>
78659	TL0026	1088	Cyberbullying	Cyberbullying is bullying that takes place using digital devices such as cell/mobile phones, computers, and tablets. Cyberbullying can occur through SMS, e-mail, apps, social media, forums, or gaming when people view, participate in, or share content. Cyberbullying includes the deliberate sending, posting, or sharing of negative, harmful, false, or mean content about someone else. It can include sharing personal or private information about someone else causing embarrassment or humiliation. Some cyberbullying may also be unlawful or criminal behaviour (US Government, 2020).
78660	TL0027	1089	Natech	Natural hazard triggered technological accident (Showalter et al., 1994).
78661	TL0028	1089	Pollution	Pollution is defined as the presence of substances and/or heat in environmental media (air, water, land) whose nature, location, or quantity produces undesirable environmental effects (UN data, no date). Alternative definition: Pollution is defined as activity that generates pollutants (UN data, no date).
78662	TL0029	1089	Explosion	Explosion-related technological incidents can be defined as accidental or intentional events that result in the actual or potential exposure of responders and/or members of the public to a chemical hazard (adapted from WHO, no date).
78663	TL0030	1089	Leaks and Spills	A leak or a spill is an incident involving the uncontrolled release of a toxic substance, potentially resulting in harm to public health and the environment. Chemical incidents can occur as a result of natural events, or as a result of accidental or intentional events. These incidents can be sudden and acute or have a slow onset when there is a ‘silent’ release of a chemical. Chemical leaks and spills can range from small releases to full-scale major emergencies (adapted from WHO, 2020).
78664	TL0031	1089	Soil Pollution	Soil pollution refers to the presence of a chemical or substance out of place and/or present in a soil at higher than normal concentration that has adverse effects on any non-targeted organism (Rodríguez-Eugenio et al., 2018).
78665	TL0032	1089	Fire	Fire related technological incidents can be defined as accidental or intentional events that result in the actual or potential exposure of responders and/or members of the public to a chemical hazard (adapted from WHO, no date)
78666	TL0033	1089	Mining Hazards	Mining hazards can be defined as having major environmental impacts including the production of waste, release of toxic and hazardous waste, air pollution and emissions, water pollution and depletion, and the loss of productive land and ecosystems (adapted from UNDP and UN Environment, 2018).
78667	TL0034	1089	Safety Hazards Associated with Oil and Gas	<p>Oil and gas extraction, and associated servicing activities involve many types of equipment and materials. Identifying and controlling hazards is critical to preventing injuries and deaths (US Department of Labor, no date).</p><p>Alternative definition: For the purpose of the C155 - Occupational Safety and Health Convention, 1981 (No. 155) (ILO, 1981):</p><p>a) the term branches of economic activity covers all branches in which workers are employed, including the public service.</p><p>b) the term workers covers all employed persons, including public employees.</p><p>c) the term workplace covers all places where workers need to be or to go by reason of their work and which are under the direct or indirect control of the employer.</p><p>d) the term regulations covers all provisions given force of law by the competent authority or authorities.</p><p>e) the term health, in relation to work, indicates not merely the absence of disease or infirmity; it also includes the physical and mental elements affecting health which are directly related to safety and hygiene at work.</p>
78668	TL0035	1090	Disaster Waste	Disaster waste is the waste generated by the impact of a disaster, both as a direct effect of the disaster as well as in the post-disaster phase as a result of poor waste management (UNEP/OCHA, 2011).
78669	TL0036	1090	Solid Waste	Solid waste covers discarded materials that are no longer required by the owner or user. Solid waste includes materials that are in a solid or liquid state but excludes wastewater and small particulate matter released into the atmosphere (United Nations, 2014).
78670	TL0037	1090	Wastewater	Wastewater is regarded as a combination of one or more of the following materials: domestic effluent consisting of ‘blackwater’ (excreta, urine and faecal sludge, contaminants from pharmaceutical and personal care products) and ‘greywater’ (used water from washing and bathing); water from commercial establishments and institutions, including hospitals; industrial effluent, stormwater and other urban runoff; and agricultural, horticultural and aquaculture runoff (UN Water, 2017).
78671	TL0038	1090	Hazardous Waste	Hazardous waste is waste that has physical, chemical, or biological characteristics such that it requires special handling and disposal procedures to avoid negative health effects, adverse environmental effects or both (Joint UNEP/OCHA Environment Unit, 2011).
78672	TL0039	1090	Plastic Waste	Plastic is a generic term used in the case of polymeric material that may contain other substances to improve performance and/or reduce costs, with plastic waste almost exclusively comprising one non-halogenated polymer and waste substances or objects which are disposed of or are intended to be disposed of or are required to be disposed of by the provisions of national law (adapted from Basel Convention, 1989; and Basel Convention Secretariat, 2019).
78673	TL0041	1090	Electronic Waste (E-Waste)	Electrical and electronic waste, or E-waste, refers to electrical or electronic equipment that is waste, including all components, subassemblies and consumables that are part of the equipment at the time the equipment becomes waste (UNEP, 2019).
78674	TL0042	1090	Healthcare Risk Waste	Healthcare waste includes waste generated within healthcare facilities, research centres and laboratories related to medical procedures and medical equipment. It also includes waste originating from minor and scattered healthcare sources, including waste produced in the course of emergency medical treatment or health care undertaken in the home (e.g., home dialysis, self-administration of insulin, recuperative care) (WHO, 2014).
78675	TL0043	1090	Landfilling	Landfilling is the final placement of waste into or onto the land in a controlled way. The definition covers both landfilling at internal sites (i.e., where a generator of waste is carrying out its own waste disposal at the place of generation) and at external sites (United Nations, 2016).
78676	TL0044	1090	Tailings	Tailings are a common by-product of the mineral recovery process. They usually take the form of a liquid slurry made of fine mineral particles (created when mined ore is crushed, ground and processed) and water (ICMM, 2019).
78677	TL0045	1090	Waste Treatment Lagoons	Waste [treatment] lagoons can be defined as impoundments made by excavation or earth fill for biological treatment of animal and other agricultural waste (Spellman and Bieber, 2012).
78678	TL0040	1091	Marine Debris	Marine debris is any persistent, manufactured or processed solid material discarded, disposed of or abandoned in the marine and coastal environment. Marine litter consists of items that have been made or used by people and deliberately discarded into the sea or rivers or on beaches; brought indirectly to the sea with rivers, sewage, storm water or winds; or accidentally lost, including material lost at sea in bad weather (adapted from UN Environment, no date; and NOAA, no date).
78679	TL0046	1092	Drain and Sewer Flooding	Drain and sewer flooding is said to occur when sewage or foul water leaks from the sewerage system (through pipes, drains or manholes) or floods up through toilets, sinks or showers inside a building (Priestly, 2016).
78680	TL0047	1092	Reservoir Flooding	A reservoir is an artificial lake where water is stored (National Geographic, 2020). Reservoir flooding occurs when excess rainfall causes the lake level to rise or flood water to spill downstream.
78681	TL0048	1093	Air Transportation Accident	An air transportation accident is defined as an occurrence associated with the operation of an aircraft which takes place between the time any person boards the aircraft with the intention of flight until such time as all such persons have disembarked, in which one of the following applies: a person is fatally or seriously injured, the aircraft sustains damage or structural failure, and the aircraft is missing or is completely inaccessible (United Nations, European Union and the International Transport Forum at the OECD, 2019:119).
78682	TL0049	1093	Inland Water Ways	An inland waterway transportation accident is an unwanted or unintended sudden event or a specific chain of such events occurring in connection with inland water vessel operations, which have harmful consequences (United Nations, European Union and the International Transport Forum at the OECD, 2019).
78683	TL0050	1093	Marine Accident	A marine accident is an event, or a sequence of events, that has resulted in any of the following occurring directly in connection with the normal operation of a marine vessel: the death of, or serious injury to, a person; the loss of a person from a ship; the loss, presumed loss or abandonment of a marine vessel; material damage to a marine vessel; the stranding or disabling of a marine vessel, or the involvement of a marine vessel in a collision; material damage to the marine infrastructures external to a vessel, that could seriously endanger the safety of the vessel or another vessel or an individual; and severe damage to the environment, or the potential for severe damage to the environment, brought about by the damage of a marine vessel (United Nations, European Union and the International Transport Forum at the OECD, 2019).
78684	TL0051	1093	Rail Accident	A rail accident is an unwanted or unintended sudden event or a specific chain of such events (occurring during train operation) which has harmful consequences (United Nations, European Union and the International Transport Forum at the OECD, 2019).
78685	TL0052	1093	Road Traffic Accident	A road traffic accident is any accident involving at least one road vehicle in motion on a public road or private road to which the public has right of access, resulting in at least one injured or killed person (United Nations, European Union and the International Transport Forum at the OECD, 2019).
81041	TL0022	1088	Disrupt	<p>A service procedure is disrupted by another service if the second service results in service primitives of the first service not being used as specified for the procedure of the first service (ITU, 2012)</p>
\.


--
-- TOC entry 6233 (class 0 OID 290357)
-- Dependencies: 249
-- Data for Name: human_category_presence; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.human_category_presence (id, record_id, deaths, injured, missing, affected_direct, affected_indirect, displaced) FROM stdin;
\.


--
-- TOC entry 6234 (class 0 OID 290361)
-- Dependencies: 250
-- Data for Name: human_dsg; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.human_dsg (id, record_id, sex, age, disability, global_poverty_line, national_poverty_line, custom) FROM stdin;
\.


--
-- TOC entry 6235 (class 0 OID 290367)
-- Dependencies: 251
-- Data for Name: human_dsg_config; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.human_dsg_config (hidden, custom) FROM stdin;
\.


--
-- TOC entry 6236 (class 0 OID 290372)
-- Dependencies: 252
-- Data for Name: injured; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.injured (id, dsg_id, injured) FROM stdin;
\.


--
-- TOC entry 6237 (class 0 OID 290376)
-- Dependencies: 253
-- Data for Name: instance_system_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instance_system_settings (id, footer_url_privacy_policy, footer_url_terms_conditions, admin_setup_complete) FROM stdin;
\.


--
-- TOC entry 6238 (class 0 OID 290383)
-- Dependencies: 254
-- Data for Name: losses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.losses (api_import_id, id, record_id, sector_id, sector_is_agriculture, type_not_agriculture, type_agriculture, related_to_not_agriculture, related_to_agriculture, description, public_value_unit, public_units, public_cost_unit, public_cost_unit_currency, public_cost_total, public_cost_total_override, private_value_unit, private_units, private_cost_unit, private_cost_unit_currency, private_cost_total, private_cost_total_override, spatial_footprint, attachments) FROM stdin;
\.


--
-- TOC entry 6239 (class 0 OID 290391)
-- Dependencies: 255
-- Data for Name: measure; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.measure (api_import_id, id, name, type) FROM stdin;
\.


--
-- TOC entry 6240 (class 0 OID 290398)
-- Dependencies: 256
-- Data for Name: missing; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.missing (id, dsg_id, as_of, missing) FROM stdin;
\.


--
-- TOC entry 6241 (class 0 OID 290402)
-- Dependencies: 257
-- Data for Name: noneco_losses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.noneco_losses (api_import_id, id, disaster_record_id, category_id, description, updated_at, created_at) FROM stdin;
\.


--
-- TOC entry 6242 (class 0 OID 290410)
-- Dependencies: 258
-- Data for Name: sector; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sector (id, parent_id, sectorname, description, level, updated_at, created_at) FROM stdin;
1	\N	Productive		1	2025-07-16 13:41:14.650774	2025-07-16 13:41:14.650774
2	\N	Social		1	2025-07-16 13:41:14.651095	2025-07-16 13:41:14.651095
3	\N	Infrastructures		1	2025-07-16 13:41:14.680672	2025-07-16 13:41:14.680672
11	1	Agriculture		2	2025-07-16 13:41:14.682482	2025-07-16 13:41:14.682482
4	\N	Cross-cutting		1	2025-07-16 13:41:14.682632	2025-07-16 13:41:14.682632
12	1	Industry		2	2025-07-16 13:41:14.683924	2025-07-16 13:41:14.683924
13	1	Tourism		2	2025-07-16 13:41:14.685564	2025-07-16 13:41:14.685564
14	1	Commerce and Trade		2	2025-07-16 13:41:14.687111	2025-07-16 13:41:14.687111
15	1	Services		2	2025-07-16 13:41:14.687823	2025-07-16 13:41:14.687823
21	2	Health		2	2025-07-16 13:41:14.688905	2025-07-16 13:41:14.688905
22	2	Education		2	2025-07-16 13:41:14.689407	2025-07-16 13:41:14.689407
23	2	Housing		2	2025-07-16 13:41:14.690381	2025-07-16 13:41:14.690381
24	2	Culture		2	2025-07-16 13:41:14.691215	2025-07-16 13:41:14.691215
31	3	Transportation		2	2025-07-16 13:41:14.691584	2025-07-16 13:41:14.691584
32	3	Energy and Electricity		2	2025-07-16 13:41:14.692176	2025-07-16 13:41:14.692176
33	3	Information and Communication		2	2025-07-16 13:41:14.692882	2025-07-16 13:41:14.692882
34	3	Water		2	2025-07-16 13:41:14.693258	2025-07-16 13:41:14.693258
35	3	Sanitation		2	2025-07-16 13:41:14.693892	2025-07-16 13:41:14.693892
36	3	Community infrastructure		2	2025-07-16 13:41:14.694562	2025-07-16 13:41:14.694562
41	4	Environment		2	2025-07-16 13:41:14.69495	2025-07-16 13:41:14.69495
42	4	Gender		2	2025-07-16 13:41:14.695539	2025-07-16 13:41:14.695539
43	4	Governance		2	2025-07-16 13:41:14.696181	2025-07-16 13:41:14.696181
44	4	Employment, Livelihoods and social protection		2	2025-07-16 13:41:14.696723	2025-07-16 13:41:14.696723
45	4	Disaster Risk Management		2	2025-07-16 13:41:14.697343	2025-07-16 13:41:14.697343
1101	11	Crops		3	2025-07-16 13:41:14.698096	2025-07-16 13:41:14.698096
1102	11	Livestock		3	2025-07-16 13:41:14.698559	2025-07-16 13:41:14.698559
1103	11	Forestry and logging		3	2025-07-16 13:41:14.700118	2025-07-16 13:41:14.700118
1104	11	Aquaculture		3	2025-07-16 13:41:14.701216	2025-07-16 13:41:14.701216
1105	11	Fisheries		3	2025-07-16 13:41:14.702188	2025-07-16 13:41:14.702188
1201	12	Mining and quarrying		3	2025-07-16 13:41:14.703159	2025-07-16 13:41:14.703159
1202	12	Manufacturing		3	2025-07-16 13:41:14.70476	2025-07-16 13:41:14.70476
1203	12	Construction		3	2025-07-16 13:41:14.705493	2025-07-16 13:41:14.705493
1301	13	Accommodation services for visitors		3	2025-07-16 13:41:14.706667	2025-07-16 13:41:14.706667
1302	13	Food and beverage services		3	2025-07-16 13:41:14.707992	2025-07-16 13:41:14.707992
1303	13	Travel agency and reservation services		3	2025-07-16 13:41:14.708653	2025-07-16 13:41:14.708653
1304	13	Recreation and other entertainment		3	2025-07-16 13:41:14.709173	2025-07-16 13:41:14.709173
1305	13	Passenger transport		3	2025-07-16 13:41:14.709788	2025-07-16 13:41:14.709788
1401	14	Wholesale trade		3	2025-07-16 13:41:14.711336	2025-07-16 13:41:14.711336
1402	14	Retail trade		3	2025-07-16 13:41:14.712264	2025-07-16 13:41:14.712264
1403	14	Sales and maintenance of vehicles		3	2025-07-16 13:41:14.713425	2025-07-16 13:41:14.713425
1501	15	Administrative and support services		3	2025-07-16 13:41:14.714949	2025-07-16 13:41:14.714949
1502	15	Professional, scientific and technical activities		3	2025-07-16 13:41:14.716445	2025-07-16 13:41:14.716445
1503	15	Real estate		3	2025-07-16 13:41:14.717178	2025-07-16 13:41:14.717178
1504	15	Finance and insurance services		3	2025-07-16 13:41:14.717592	2025-07-16 13:41:14.717592
2101	21	Health care network		3	2025-07-16 13:41:14.718304	2025-07-16 13:41:14.718304
2102	21	Health programs and other services		3	2025-07-16 13:41:14.719549	2025-07-16 13:41:14.719549
2103	21	Health care systems' management		3	2025-07-16 13:41:14.72051	2025-07-16 13:41:14.72051
2201	22	0-Early childhood		3	2025-07-16 13:41:14.72173	2025-07-16 13:41:14.72173
2202	22	1-Primary education		3	2025-07-16 13:41:14.72341	2025-07-16 13:41:14.72341
2203	22	2-3- Secondary		3	2025-07-16 13:41:14.72394	2025-07-16 13:41:14.72394
2204	22	4- Post secondary		3	2025-07-16 13:41:14.724487	2025-07-16 13:41:14.724487
2205	22	5-8 Tertiary		3	2025-07-16 13:41:14.725835	2025-07-16 13:41:14.725835
2206	22	Others -Non-formal education		3	2025-07-16 13:41:14.726308	2025-07-16 13:41:14.726308
2301	23	Housing units		3	2025-07-16 13:41:14.726771	2025-07-16 13:41:14.726771
2302	23	Collective living quarters		3	2025-07-16 13:41:14.728498	2025-07-16 13:41:14.728498
2401	24	Tangible Cultural heritage		3	2025-07-16 13:41:14.728988	2025-07-16 13:41:14.728988
2402	24	Intangible cultural heritage		3	2025-07-16 13:41:14.730304	2025-07-16 13:41:14.730304
3101	31	Land Transportation		3	2025-07-16 13:41:14.730924	2025-07-16 13:41:14.730924
3102	31	Air Transportation		3	2025-07-16 13:41:14.73126	2025-07-16 13:41:14.73126
3103	31	Water transportation		3	2025-07-16 13:41:14.732463	2025-07-16 13:41:14.732463
3104	31	Transportation supppor services		3	2025-07-16 13:41:14.734569	2025-07-16 13:41:14.734569
3105	31	Postal and courier services		3	2025-07-16 13:41:14.735828	2025-07-16 13:41:14.735828
3201	32	Electricity		3	2025-07-16 13:41:14.736817	2025-07-16 13:41:14.736817
3202	32	Consumable fuels		3	2025-07-16 13:41:14.738212	2025-07-16 13:41:14.738212
3301	33	Publishing		3	2025-07-16 13:41:14.738897	2025-07-16 13:41:14.738897
3302	33	Motion picture, video and TV program production, sound and music recording		3	2025-07-16 13:41:14.739465	2025-07-16 13:41:14.739465
3303	33	Telecommunications;		3	2025-07-16 13:41:14.740074	2025-07-16 13:41:14.740074
3304	33	Computer programming, consultancy and related		3	2025-07-16 13:41:14.741261	2025-07-16 13:41:14.741261
3305	33	Information services		3	2025-07-16 13:41:14.742447	2025-07-16 13:41:14.742447
3306	33	Others		3	2025-07-16 13:41:14.743049	2025-07-16 13:41:14.743049
3401	34	Water sources- generation		3	2025-07-16 13:41:14.743433	2025-07-16 13:41:14.743433
3402	34	Water treatment		3	2025-07-16 13:41:14.743895	2025-07-16 13:41:14.743895
3403	34	Water distribution		3	2025-07-16 13:41:14.744384	2025-07-16 13:41:14.744384
3501	35	Large scale sanitation		3	2025-07-16 13:41:14.745766	2025-07-16 13:41:14.745766
3502	35	Small scale sanitation		3	2025-07-16 13:41:14.746321	2025-07-16 13:41:14.746321
3503	35	Urban solid waste		3	2025-07-16 13:41:14.746767	2025-07-16 13:41:14.746767
3504	35	Hazardous waste		3	2025-07-16 13:41:14.748411	2025-07-16 13:41:14.748411
3601	36	Connective infrastructure		3	2025-07-16 13:41:14.749014	2025-07-16 13:41:14.749014
3602	36	Protective infrastructure		3	2025-07-16 13:41:14.750232	2025-07-16 13:41:14.750232
3603	36	Socio-economic structures		3	2025-07-16 13:41:14.752157	2025-07-16 13:41:14.752157
3604	36	Community Water and sanitation lifelines		3	2025-07-16 13:41:14.753396	2025-07-16 13:41:14.753396
3605	36	Community energy lifelines off-grid		3	2025-07-16 13:41:14.754725	2025-07-16 13:41:14.754725
3606	36	Commnications community lifelines		3	2025-07-16 13:41:14.757423	2025-07-16 13:41:14.757423
4101	41	Biodiversity		3	2025-07-16 13:41:14.758672	2025-07-16 13:41:14.758672
4102	41	Natural Ressources		3	2025-07-16 13:41:14.759737	2025-07-16 13:41:14.759737
4103	41	Ecosystem services		3	2025-07-16 13:41:14.761546	2025-07-16 13:41:14.761546
4201	42	Gender inequalities		3	2025-07-16 13:41:14.762652	2025-07-16 13:41:14.762652
4202	42	Gender-based violence		3	2025-07-16 13:41:14.763686	2025-07-16 13:41:14.763686
4303	42	Legislative power		3	2025-07-16 13:41:14.767676	2025-07-16 13:41:14.767676
4402	44	Livelihoods		3	2025-07-16 13:41:14.77142	2025-07-16 13:41:14.77142
4503	45	Disaster mitigation		3	2025-07-16 13:41:14.774607	2025-07-16 13:41:14.774607
1101002	1101	Permanent- perennial crops		4	2025-07-16 13:41:14.776649	2025-07-16 13:41:14.776649
1102002	1102	Hunting and trapping		4	2025-07-16 13:41:14.778557	2025-07-16 13:41:14.778557
1104002	1104	Freshwater aquaculture		4	2025-07-16 13:41:14.784058	2025-07-16 13:41:14.784058
1201001	1201	Mining of coal and lignite		4	2025-07-16 13:41:14.786855	2025-07-16 13:41:14.786855
1201005	1201	Other mining and quarrying		4	2025-07-16 13:41:14.792428	2025-07-16 13:41:14.792428
1202002	1202	Manufacture of beverages		4	2025-07-16 13:41:14.795461	2025-07-16 13:41:14.795461
1202005	1202	Manufacture of wearing apparel		4	2025-07-16 13:41:14.798245	2025-07-16 13:41:14.798245
1202008	1202	Manufacture of paper and paper products		4	2025-07-16 13:41:14.801703	2025-07-16 13:41:14.801703
1202011	1202	Manufacture of chemicals and chemical products		4	2025-07-16 13:41:14.804499	2025-07-16 13:41:14.804499
1202014	1202	Manufacture of other non metallic mineral products		4	2025-07-16 13:41:14.807786	2025-07-16 13:41:14.807786
1202017	1202	Manufacture of computer, electronic and optical products		4	2025-07-16 13:41:14.811451	2025-07-16 13:41:14.811451
1202020	1202	Manufacture of motor vehicles, trailers and semi trailers		4	2025-07-16 13:41:14.815584	2025-07-16 13:41:14.815584
1202023	1202	Other manufacturing		4	2025-07-16 13:41:14.81958	2025-07-16 13:41:14.81958
1203003	1203	Specialized construction activities		4	2025-07-16 13:41:14.823437	2025-07-16 13:41:14.823437
1301002	1301	Accommodation in camping grounds, recreational vehicle parks and trailer parks;		4	2025-07-16 13:41:14.825304	2025-07-16 13:41:14.825304
1302003	1302	Beverage serving activities in bars, taverns, cocktail lounges, discotheques, beer parlors and pubs, coffee shops, fruit juice bars, and mobile beverage vendors.		4	2025-07-16 13:41:14.830872	2025-07-16 13:41:14.830872
1303002	1303	Wholesale travel agencies		4	2025-07-16 13:41:14.834384	2025-07-16 13:41:14.834384
1304001	1304	Sport and recreational activities		4	2025-07-16 13:41:14.837955	2025-07-16 13:41:14.837955
1305002	1305	Air passenger transport		4	2025-07-16 13:41:14.841465	2025-07-16 13:41:14.841465
1401001	1401	Wholesale on a fee or contract basis		4	2025-07-16 13:41:14.845399	2025-07-16 13:41:14.845399
1401004	1401	Wholesale of household goods		4	2025-07-16 13:41:14.849376	2025-07-16 13:41:14.849376
1401007	1401	Non-specialized wholesale trade		4	2025-07-16 13:41:14.854458	2025-07-16 13:41:14.854458
1402002	1402	Retail trade non in stores		4	2025-07-16 13:41:14.858199	2025-07-16 13:41:14.858199
1403002	1403	Maintenance and repair of motor vehicles		4	2025-07-16 13:41:14.860276	2025-07-16 13:41:14.860276
1403005	1403	Others		4	2025-07-16 13:41:14.862696	2025-07-16 13:41:14.862696
1501002	1501	Employment activities		4	2025-07-16 13:41:14.864599	2025-07-16 13:41:14.864599
1501004	1501	Services to buildings and landscape activities		4	2025-07-16 13:41:14.866451	2025-07-16 13:41:14.866451
1502002	1502	Activities of head offices; management consultancy activities		4	2025-07-16 13:41:14.868722	2025-07-16 13:41:14.868722
1502005	1502	Scientific research and development		4	2025-07-16 13:41:14.872733	2025-07-16 13:41:14.872733
1502007	1502	Veterinary activities		4	2025-07-16 13:41:14.876938	2025-07-16 13:41:14.876938
1504002	1504	Holding companies		4	2025-07-16 13:41:14.882193	2025-07-16 13:41:14.882193
1504005	1504	Insurance		4	2025-07-16 13:41:14.883411	2025-07-16 13:41:14.883411
1504008	1504	Activities auxiliary to financial service and insurance activities		4	2025-07-16 13:41:14.885864	2025-07-16 13:41:14.885864
2101002	2101	primary health care		4	2025-07-16 13:41:14.890106	2025-07-16 13:41:14.890106
2102001	2102	Telemedicine		4	2025-07-16 13:41:14.893252	2025-07-16 13:41:14.893252
2102004	2102	Emergency medical services		4	2025-07-16 13:41:14.894581	2025-07-16 13:41:14.894581
2102007	2102	Immunization programs		4	2025-07-16 13:41:14.898246	2025-07-16 13:41:14.898246
2102010	2102	Non-communicable diseases programs		4	2025-07-16 13:41:14.902056	2025-07-16 13:41:14.902056
2102013	2102	Health surveillance and early warning		4	2025-07-16 13:41:14.905	2025-07-16 13:41:14.905
2201001	2201	01 Early childhood educational\n development ( below 3)		4	2025-07-16 13:41:14.907886	2025-07-16 13:41:14.907886
2202001	2202	Primary education		4	2025-07-16 13:41:14.909739	2025-07-16 13:41:14.909739
2203002	2203	3 Upper secondary / High school		4	2025-07-16 13:41:14.910601	2025-07-16 13:41:14.910601
2205001	2205	5 -Short-cycle tertiary education ( general or vocational)		4	2025-07-16 13:41:14.915231	2025-07-16 13:41:14.915231
2206002	2206	Community education		4	2025-07-16 13:41:14.920304	2025-07-16 13:41:14.920304
2206006	2206	Other non-formal education		4	2025-07-16 13:41:14.922451	2025-07-16 13:41:14.922451
2301003	2301	Other housing units		4	2025-07-16 13:41:14.926893	2025-07-16 13:41:14.926893
2302003	2302	Camps and workers quarters		4	2025-07-16 13:41:14.931118	2025-07-16 13:41:14.931118
2401002	2401	Cultural sites		4	2025-07-16 13:41:14.934332	2025-07-16 13:41:14.934332
2401005	2401	Repositories of heritage		4	2025-07-16 13:41:14.937718	2025-07-16 13:41:14.937718
2402001	2402	landscapes,		4	2025-07-16 13:41:14.940071	2025-07-16 13:41:14.940071
2402003	2402	rituals,		4	2025-07-16 13:41:14.941073	2025-07-16 13:41:14.941073
3101002	3101	Railroad transport		4	2025-07-16 13:41:14.943667	2025-07-16 13:41:14.943667
3101004	3101	Other land transport		4	2025-07-16 13:41:14.944606	2025-07-16 13:41:14.944606
3103001	3103	Sea and coastal		4	2025-07-16 13:41:14.947936	2025-07-16 13:41:14.947936
3104001	3104	Warehousing and storage		4	2025-07-16 13:41:14.951085	2025-07-16 13:41:14.951085
3105002	3105	Courier activities		4	2025-07-16 13:41:14.954853	2025-07-16 13:41:14.954853
3201002	3201	Renewable		4	2025-07-16 13:41:14.957119	2025-07-16 13:41:14.957119
3201006	3201	Low voltage		4	2025-07-16 13:41:14.95964	2025-07-16 13:41:14.95964
3201008	3201	Industrial network		4	2025-07-16 13:41:14.960598	2025-07-16 13:41:14.960598
3202001	3202	Natural gas- upstream		4	2025-07-16 13:41:14.963684	2025-07-16 13:41:14.963684
3202005	3202	Oil Manufacture/ upstream		4	2025-07-16 13:41:14.966535	2025-07-16 13:41:14.966535
3202007	3202	Oil strorage		4	2025-07-16 13:41:14.967551	2025-07-16 13:41:14.967551
3202011	3202	Steam Generation		4	2025-07-16 13:41:14.969254	2025-07-16 13:41:14.969254
3202014	3202	Hot water Distribution		4	2025-07-16 13:41:14.971121	2025-07-16 13:41:14.971121
3303003	3303	Satellite telecommunication activities;		4	2025-07-16 13:41:14.973906	2025-07-16 13:41:14.973906
3401001	3401	From Surface water		4	2025-07-16 13:41:14.974779	2025-07-16 13:41:14.974779
3401003	3401	From Soil water		4	2025-07-16 13:41:14.97571	2025-07-16 13:41:14.97571
3401005	3401	From Reclaimed		4	2025-07-16 13:41:14.977656	2025-07-16 13:41:14.977656
3402002	3402	Chemical water treatment		4	2025-07-16 13:41:14.981742	2025-07-16 13:41:14.981742
3403001	3403	Piped water distribution		4	2025-07-16 13:41:14.985597	2025-07-16 13:41:14.985597
3501001	3501	Urban sewage system		4	2025-07-16 13:41:14.987125	2025-07-16 13:41:14.987125
3501004	3501	pumping systems		4	2025-07-16 13:41:14.989542	2025-07-16 13:41:14.989542
3503003	3503	Waste transportation		4	2025-07-16 13:41:14.99223	2025-07-16 13:41:14.99223
3504002	3504	Waste processing and treatment		4	2025-07-16 13:41:14.994653	2025-07-16 13:41:14.994653
4101001	4101	Species		4	2025-07-16 13:41:14.996604	2025-07-16 13:41:14.996604
4102001	4102	Land ( including soils)		4	2025-07-16 13:41:14.999207	2025-07-16 13:41:14.999207
4301	42	Public administration		3	2025-07-16 13:41:14.764923	2025-07-16 13:41:14.764923
4304	42	Judiciary power		3	2025-07-16 13:41:14.769288	2025-07-16 13:41:14.769288
4501	45	Disaster management		3	2025-07-16 13:41:14.77343	2025-07-16 13:41:14.77343
1102001	1102	Animal production		4	2025-07-16 13:41:14.777129	2025-07-16 13:41:14.777129
1103001	1103	Silviculture		4	2025-07-16 13:41:14.779124	2025-07-16 13:41:14.779124
1103003	1103	Gathering forest products		4	2025-07-16 13:41:14.781153	2025-07-16 13:41:14.781153
1105002	1105	Freshwater fishing		4	2025-07-16 13:41:14.785725	2025-07-16 13:41:14.785725
1201003	1201	Mining of metal ores		4	2025-07-16 13:41:14.789143	2025-07-16 13:41:14.789143
1201006	1201	Mining support service activities		4	2025-07-16 13:41:14.793428	2025-07-16 13:41:14.793428
1202003	1202	Manufacture of tobacco products		4	2025-07-16 13:41:14.796424	2025-07-16 13:41:14.796424
1202006	1202	Manufacture of leather and related products		4	2025-07-16 13:41:14.798928	2025-07-16 13:41:14.798928
1202009	1202	Printing and reproduction of recorded media		4	2025-07-16 13:41:14.803062	2025-07-16 13:41:14.803062
1202012	1202	Manufacture of basic pharmaceutical products and pharmaceutical preparations		4	2025-07-16 13:41:14.805029	2025-07-16 13:41:14.805029
1202015	1202	Manufacture of basic metals		4	2025-07-16 13:41:14.809318	2025-07-16 13:41:14.809318
1202018	1202	Manufacture of electrical equipment		4	2025-07-16 13:41:14.813479	2025-07-16 13:41:14.813479
1202021	1202	Manufacture of other transport equipment		4	2025-07-16 13:41:14.816674	2025-07-16 13:41:14.816674
1202024	1202	Repair and installation of machinery and equipment		4	2025-07-16 13:41:14.820893	2025-07-16 13:41:14.820893
1203002	1203	Civil engineering		4	2025-07-16 13:41:14.822692	2025-07-16 13:41:14.822692
1301001	1301	Short-term accommodation in hotels, resort hotels, suite/apartment hotels, motels, motor hotels, guest houses, pensions, bed-and-breakfast units, visitor flats and bungalows, time-share units, holiday homes, chalets, housekeeping cottages and cabins, and youth hostel and mountain refuges;		4	2025-07-16 13:41:14.823976	2025-07-16 13:41:14.823976
1301003	1301	Accommodation in student residences, school dormitories, workers’ hostels, rooming and boarding houses		4	2025-07-16 13:41:14.825856	2025-07-16 13:41:14.825856
1302001	1302	Provision of food service to customers in restaurants, cafeterias, fast food restaurants, pizza delivery, take out eating places, ice-cream truck vendors, mobile food carts, food preparation in market stalls;		4	2025-07-16 13:41:14.82847	2025-07-16 13:41:14.82847
1302004	1302	Other food and beverage services		4	2025-07-16 13:41:14.832098	2025-07-16 13:41:14.832098
1303003	1303	Online travel agencies		4	2025-07-16 13:41:14.835431	2025-07-16 13:41:14.835431
1304002	1304	Cultural activities		4	2025-07-16 13:41:14.839305	2025-07-16 13:41:14.839305
1305003	1305	water passenger transport		4	2025-07-16 13:41:14.842457	2025-07-16 13:41:14.842457
1401003	1401	Wholesale of food, beverages and tobacco		4	2025-07-16 13:41:14.847995	2025-07-16 13:41:14.847995
1401006	1401	Other specialized wholesale		4	2025-07-16 13:41:14.853702	2025-07-16 13:41:14.853702
1402001	1402	Retail trade in stores		4	2025-07-16 13:41:14.856798	2025-07-16 13:41:14.856798
1403001	1403	Sale of motor vehicles		4	2025-07-16 13:41:14.859566	2025-07-16 13:41:14.859566
1403004	1403	Sale, maintenance and repair of motorcycles and related parts and accessories		4	2025-07-16 13:41:14.862116	2025-07-16 13:41:14.862116
1501003	1501	Security and investigation activities		4	2025-07-16 13:41:14.865823	2025-07-16 13:41:14.865823
1501005	1501	Office administrative, office support and other business support activities		4	2025-07-16 13:41:14.866901	2025-07-16 13:41:14.866901
1502003	1502	Architectural and engineering activities; technical testing and analysis		4	2025-07-16 13:41:14.870423	2025-07-16 13:41:14.870423
1502006	1502	Other professional, scientific and technical activities		4	2025-07-16 13:41:14.875543	2025-07-16 13:41:14.875543
1503002	1503	Real estate activities on a fee or contract basis		4	2025-07-16 13:41:14.879467	2025-07-16 13:41:14.879467
1504004	1504	Other financing services		4	2025-07-16 13:41:14.883031	2025-07-16 13:41:14.883031
1504007	1504	Pension funding		4	2025-07-16 13:41:14.885139	2025-07-16 13:41:14.885139
1504009	1504	Fund management activities		4	2025-07-16 13:41:14.887318	2025-07-16 13:41:14.887318
2101003	2101	secondary		4	2025-07-16 13:41:14.891191	2025-07-16 13:41:14.891191
2101005	2101	Other-non categorized		4	2025-07-16 13:41:14.892784	2025-07-16 13:41:14.892784
2102002	2102	Sexual and reproductive health		4	2025-07-16 13:41:14.893712	2025-07-16 13:41:14.893712
2102005	2102	Environmental health		4	2025-07-16 13:41:14.895895	2025-07-16 13:41:14.895895
2102008	2102	Mental health		4	2025-07-16 13:41:14.899356	2025-07-16 13:41:14.899356
2102011	2102	Nutrition		4	2025-07-16 13:41:14.902895	2025-07-16 13:41:14.902895
2102014	2102	Other health services		4	2025-07-16 13:41:14.905989	2025-07-16 13:41:14.905989
2201002	2201	Early childhood\n (02 Pre-primary - 3 to start primary)		4	2025-07-16 13:41:14.909224	2025-07-16 13:41:14.909224
2204001	2204	General		4	2025-07-16 13:41:14.91206	2025-07-16 13:41:14.91206
2205002	2205	6,7,8-Bachelors, Master, Phd ( academic or professional)		4	2025-07-16 13:41:14.916569	2025-07-16 13:41:14.916569
2206004	2206	Others - Adult language centers		4	2025-07-16 13:41:14.921514	2025-07-16 13:41:14.921514
2301001	2301	With all basic facilities		4	2025-07-16 13:41:14.923779	2025-07-16 13:41:14.923779
2302001	2302	Rooming houses and lodging		4	2025-07-16 13:41:14.927995	2025-07-16 13:41:14.927995
2302004	2302	Other collectiving living quarters		4	2025-07-16 13:41:14.93223	2025-07-16 13:41:14.93223
2401003	2401	Natural sites		4	2025-07-16 13:41:14.935469	2025-07-16 13:41:14.935469
2401006	2401	Urban heritage		4	2025-07-16 13:41:14.938936	2025-07-16 13:41:14.938936
2402005	2402	language		4	2025-07-16 13:41:14.942061	2025-07-16 13:41:14.942061
3101001	3101	Road transport infrastructure		4	2025-07-16 13:41:14.9432	2025-07-16 13:41:14.9432
3101003	3101	Pipeline transport		4	2025-07-16 13:41:14.944179	2025-07-16 13:41:14.944179
4303002	4303	Upper Chamber/Senate		4	2025-07-16 13:41:15.024773	2025-07-16 13:41:15.024773
4401001	4401	Employees		4	2025-07-16 13:41:15.027014	2025-07-16 13:41:15.027014
4402001	4402	Commerce livelihoods		4	2025-07-16 13:41:15.030218	2025-07-16 13:41:15.030218
4402004	4402	Handicraft livelihoods		4	2025-07-16 13:41:15.033208	2025-07-16 13:41:15.033208
4402007	4402	Industry livelihoods		4	2025-07-16 13:41:15.036095	2025-07-16 13:41:15.036095
4501002	4501	Aid coordination		4	2025-07-16 13:41:15.037707	2025-07-16 13:41:15.037707
4302	42	Executive power		3	2025-07-16 13:41:14.766053	2025-07-16 13:41:14.766053
4401	44	Employment		3	2025-07-16 13:41:14.770011	2025-07-16 13:41:14.770011
4403	44	Social protection		3	2025-07-16 13:41:14.772039	2025-07-16 13:41:14.772039
4502	45	Disaster Recovery		3	2025-07-16 13:41:14.773957	2025-07-16 13:41:14.773957
1101001	1101	Temporary - annual crops		4	2025-07-16 13:41:14.776178	2025-07-16 13:41:14.776178
1103002	1103	Logging		4	2025-07-16 13:41:14.779717	2025-07-16 13:41:14.779717
1104001	1104	Marine aquaculture		4	2025-07-16 13:41:14.78283	2025-07-16 13:41:14.78283
1105001	1105	Marine fishing		4	2025-07-16 13:41:14.784625	2025-07-16 13:41:14.784625
1201002	1201	Extraction of crude petroleum and natural gas		4	2025-07-16 13:41:14.787955	2025-07-16 13:41:14.787955
1201004	1201	Mining of iron ores		4	2025-07-16 13:41:14.791298	2025-07-16 13:41:14.791298
1202001	1202	Manufacture of food products		4	2025-07-16 13:41:14.794408	2025-07-16 13:41:14.794408
1202004	1202	Manufacture of textiles		4	2025-07-16 13:41:14.797516	2025-07-16 13:41:14.797516
1202007	1202	Manufacture of wood and of products of wood and cork, except furniture; manufacture of articles of straw and plaiting materials		4	2025-07-16 13:41:14.800206	2025-07-16 13:41:14.800206
1202010	1202	Manufacture of coke and refined petroleum products		4	2025-07-16 13:41:14.803849	2025-07-16 13:41:14.803849
1202013	1202	Manufacture of rubber and plastics products		4	2025-07-16 13:41:14.806511	2025-07-16 13:41:14.806511
1202016	1202	Manufacture of fabricated metal products		4	2025-07-16 13:41:14.810259	2025-07-16 13:41:14.810259
1202019	1202	Manufacture of machinery and equipment		4	2025-07-16 13:41:14.814548	2025-07-16 13:41:14.814548
1202022	1202	Manufacture of furniture		4	2025-07-16 13:41:14.817777	2025-07-16 13:41:14.817777
1203001	1203	Construction of buildings		4	2025-07-16 13:41:14.822163	2025-07-16 13:41:14.822163
1301004	1301	Other accomodation services		4	2025-07-16 13:41:14.826437	2025-07-16 13:41:14.826437
1302002	1302	Event catering and other food-service activities;		4	2025-07-16 13:41:14.829725	2025-07-16 13:41:14.829725
1303001	1303	Retail travel agencies		4	2025-07-16 13:41:14.833308	2025-07-16 13:41:14.833308
1303004	1303	Tour operators		4	2025-07-16 13:41:14.836794	2025-07-16 13:41:14.836794
1305001	1305	Road passenger transport		4	2025-07-16 13:41:14.840479	2025-07-16 13:41:14.840479
1305004	1305	railway passenger transport		4	2025-07-16 13:41:14.843383	2025-07-16 13:41:14.843383
1401002	1401	Wholesale of agricultural raw materials and live animals		4	2025-07-16 13:41:14.846764	2025-07-16 13:41:14.846764
1401005	1401	Wholesale of machinery, equipment and supplies		4	2025-07-16 13:41:14.852029	2025-07-16 13:41:14.852029
1401008	1401	Other wholesade trade		4	2025-07-16 13:41:14.856159	2025-07-16 13:41:14.856159
1402003	1402	Other retail trade		4	2025-07-16 13:41:14.858629	2025-07-16 13:41:14.858629
1403003	1403	Sale of motor vehicle parts and accessories		4	2025-07-16 13:41:14.861002	2025-07-16 13:41:14.861002
1501001	1501	Rental and leasing activities		4	2025-07-16 13:41:14.863322	2025-07-16 13:41:14.863322
1502001	1502	legal and accounting activities		4	2025-07-16 13:41:14.867297	2025-07-16 13:41:14.867297
1502004	1502	Scientific research and development		4	2025-07-16 13:41:14.871615	2025-07-16 13:41:14.871615
1503001	1503	real estate with own or leased property		4	2025-07-16 13:41:14.878111	2025-07-16 13:41:14.878111
1504001	1504	Monetary intermediation		4	2025-07-16 13:41:14.880732	2025-07-16 13:41:14.880732
1504003	1504	Trusts, funds and similar financial entities		4	2025-07-16 13:41:14.882605	2025-07-16 13:41:14.882605
1504006	1504	Reinsurance		4	2025-07-16 13:41:14.884525	2025-07-16 13:41:14.884525
2101001	2101	community-based		4	2025-07-16 13:41:14.889054	2025-07-16 13:41:14.889054
2101004	2101	tertiary levels		4	2025-07-16 13:41:14.892229	2025-07-16 13:41:14.892229
2102003	2102	Health education		4	2025-07-16 13:41:14.894166	2025-07-16 13:41:14.894166
2102006	2102	One health		4	2025-07-16 13:41:14.897068	2025-07-16 13:41:14.897068
2102009	2102	Communicable diseases programs		4	2025-07-16 13:41:14.900996	2025-07-16 13:41:14.900996
2102012	2102	Family planning		4	2025-07-16 13:41:14.903916	2025-07-16 13:41:14.903916
2103001	2103	Health information systems		4	2025-07-16 13:41:14.906565	2025-07-16 13:41:14.906565
2203001	2203	2- Lower secondary - middle school		4	2025-07-16 13:41:14.9102	2025-07-16 13:41:14.9102
2204002	2204	Vocational		4	2025-07-16 13:41:14.913983	2025-07-16 13:41:14.913983
2206001	2206	Adult education/ literacy programs		4	2025-07-16 13:41:14.918088	2025-07-16 13:41:14.918088
2206003	2206	Continuing professional development programs		4	2025-07-16 13:41:14.920936	2025-07-16 13:41:14.920936
2206005	2206	Others -lifelong learning		4	2025-07-16 13:41:14.921977	2025-07-16 13:41:14.921977
2301002	2301	Conventional dwellings		4	2025-07-16 13:41:14.925316	2025-07-16 13:41:14.925316
2302002	2302	Institutions		4	2025-07-16 13:41:14.929913	2025-07-16 13:41:14.929913
2401001	2401	Built heritage		4	2025-07-16 13:41:14.933362	2025-07-16 13:41:14.933362
2401004	2401	Movable properties and collections		4	2025-07-16 13:41:14.936601	2025-07-16 13:41:14.936601
2401007	2401	Other tangible heritage designations		4	2025-07-16 13:41:14.939434	2025-07-16 13:41:14.939434
2402002	2402	traditional knowledge,		4	2025-07-16 13:41:14.940572	2025-07-16 13:41:14.940572
2402004	2402	festivals,		4	2025-07-16 13:41:14.941562	2025-07-16 13:41:14.941562
2402006	2402	cultural practices		4	2025-07-16 13:41:14.942729	2025-07-16 13:41:14.942729
3102001	3102	Passenger air transport		4	2025-07-16 13:41:14.945685	2025-07-16 13:41:14.945685
3103002	3103	Inland water transport		4	2025-07-16 13:41:14.948974	2025-07-16 13:41:14.948974
3104002	3104	Support activities for transportation		4	2025-07-16 13:41:14.952794	2025-07-16 13:41:14.952794
3105001	3105	Postal activities		4	2025-07-16 13:41:14.953804	2025-07-16 13:41:14.953804
3201003	3201	Electricity Storage		4	2025-07-16 13:41:14.958245	2025-07-16 13:41:14.958245
3201005	3201	Medium voltage		4	2025-07-16 13:41:14.959209	2025-07-16 13:41:14.959209
3201009	3201	Other specials network		4	2025-07-16 13:41:14.961913	2025-07-16 13:41:14.961913
3202002	3202	Natural Gas processing		4	2025-07-16 13:41:14.964273	2025-07-16 13:41:14.964273
3202004	3202	Gas Distribution		4	2025-07-16 13:41:14.965522	2025-07-16 13:41:14.965522
3202008	3202	Oil Distribution through mains		4	2025-07-16 13:41:14.967972	2025-07-16 13:41:14.967972
3202010	3202	Coal Distribution		4	2025-07-16 13:41:14.968716	2025-07-16 13:41:14.968716
3202013	3202	Hot water Generation		4	2025-07-16 13:41:14.970614	2025-07-16 13:41:14.970614
3303002	3303	Wireless telecommunication activities;		4	2025-07-16 13:41:14.972693	2025-07-16 13:41:14.972693
3401002	3401	From Ground water		4	2025-07-16 13:41:14.975221	2025-07-16 13:41:14.975221
3401006	3401	From Rainwater harvested		4	2025-07-16 13:41:14.978076	2025-07-16 13:41:14.978076
3402001	3402	Physical water treatment		4	2025-07-16 13:41:14.980105	2025-07-16 13:41:14.980105
3402003	3402	Biological water treatment		4	2025-07-16 13:41:14.98229	2025-07-16 13:41:14.98229
3402005	3402	Other treatment system		4	2025-07-16 13:41:14.984348	2025-07-16 13:41:14.984348
3501002	3501	Storm and runoff collection systems		4	2025-07-16 13:41:14.987834	2025-07-16 13:41:14.987834
3503001	3503	Waste collection		4	2025-07-16 13:41:14.99041	2025-07-16 13:41:14.99041
3503004	3503	Waste disposal		4	2025-07-16 13:41:14.992994	2025-07-16 13:41:14.992994
3504003	3504	Waste transportation		4	2025-07-16 13:41:14.99518	2025-07-16 13:41:14.99518
4101002	4101	Habitats		4	2025-07-16 13:41:14.99734	2025-07-16 13:41:14.99734
4101004	4101	Landscapes		4	2025-07-16 13:41:14.998642	2025-07-16 13:41:14.998642
4102003	4102	Primary forest		4	2025-07-16 13:41:15.000427	2025-07-16 13:41:15.000427
3102002	3102	Freight air transport		4	2025-07-16 13:41:14.946827	2025-07-16 13:41:14.946827
3103003	3103	Other water transportation		4	2025-07-16 13:41:14.949925	2025-07-16 13:41:14.949925
3104003	3104	Other transportation support activities		4	2025-07-16 13:41:14.953408	2025-07-16 13:41:14.953408
3201001	3201	Non Renewable		4	2025-07-16 13:41:14.956107	2025-07-16 13:41:14.956107
3201004	3201	Extra/ultra/high voltage		4	2025-07-16 13:41:14.958804	2025-07-16 13:41:14.958804
3201007	3201	Residential and commercial network		4	2025-07-16 13:41:14.960179	2025-07-16 13:41:14.960179
3202003	3202	Natural Gas storage		4	2025-07-16 13:41:14.964751	2025-07-16 13:41:14.964751
3202006	3202	Oil refinery		4	2025-07-16 13:41:14.967169	2025-07-16 13:41:14.967169
3202009	3202	Coal Generation		4	2025-07-16 13:41:14.968421	2025-07-16 13:41:14.968421
3202012	3202	Steam Distribution		4	2025-07-16 13:41:14.970021	2025-07-16 13:41:14.970021
3303001	3303	Wired telecommunication activities;		4	2025-07-16 13:41:14.971547	2025-07-16 13:41:14.971547
3304001	3304	Other telecommunications activities		4	2025-07-16 13:41:14.974459	2025-07-16 13:41:14.974459
3401004	3401	Desalination		4	2025-07-16 13:41:14.977194	2025-07-16 13:41:14.977194
3401007	3401	Other water sources		4	2025-07-16 13:41:14.979547	2025-07-16 13:41:14.979547
3402004	3402	Thermal water treatment		4	2025-07-16 13:41:14.983713	2025-07-16 13:41:14.983713
3403002	3403	Non-piped water distribution		4	2025-07-16 13:41:14.986426	2025-07-16 13:41:14.986426
3501003	3501	Wastewater and sewage treatment facilities		4	2025-07-16 13:41:14.988571	2025-07-16 13:41:14.988571
3503002	3503	Waste processing and treatment		4	2025-07-16 13:41:14.991481	2025-07-16 13:41:14.991481
3504001	3504	Waste collection		4	2025-07-16 13:41:14.993926	2025-07-16 13:41:14.993926
3504004	3504	Waste disposal		4	2025-07-16 13:41:14.995948	2025-07-16 13:41:14.995948
4101003	4101	Ecosystems		4	2025-07-16 13:41:14.998047	2025-07-16 13:41:14.998047
4102002	4102	Agricultural land		4	2025-07-16 13:41:14.999798	2025-07-16 13:41:14.999798
4102005	4102	Other natural resources		4	2025-07-16 13:41:15.002433	2025-07-16 13:41:15.002433
4103003	4103	Provisioning services		4	2025-07-16 13:41:15.004595	2025-07-16 13:41:15.004595
4201002	4201	Access to ressources		4	2025-07-16 13:41:15.007504	2025-07-16 13:41:15.007504
4201005	4201	Productive Asset ownership		4	2025-07-16 13:41:15.011423	2025-07-16 13:41:15.011423
4202001	4202	Physical violence		4	2025-07-16 13:41:15.014664	2025-07-16 13:41:15.014664
4202004	4202	Economic abuse		4	2025-07-16 13:41:15.019098	2025-07-16 13:41:15.019098
4202006	4202	Cyber or online abuse		4	2025-07-16 13:41:15.020817	2025-07-16 13:41:15.020817
4301003	4301	Local administration		4	2025-07-16 13:41:15.022518	2025-07-16 13:41:15.022518
4102004	4102	Freshwater		4	2025-07-16 13:41:15.001371	2025-07-16 13:41:15.001371
4103002	4103	Regulating Services		4	2025-07-16 13:41:15.004093	2025-07-16 13:41:15.004093
4201001	4201	Time-use		4	2025-07-16 13:41:15.006241	2025-07-16 13:41:15.006241
4201003	4201	Access to services		4	2025-07-16 13:41:15.008825	2025-07-16 13:41:15.008825
4201007	4201	Gender-based discrimination		4	2025-07-16 13:41:15.013449	2025-07-16 13:41:15.013449
4202002	4202	Sexual violence		4	2025-07-16 13:41:15.016581	2025-07-16 13:41:15.016581
4301002	4301	Regional - Decentralized Administration		4	2025-07-16 13:41:15.021933	2025-07-16 13:41:15.021933
4303001	4303	Parlaments/ Congress/ Lower chamber		4	2025-07-16 13:41:15.023803	2025-07-16 13:41:15.023803
4304001	4304	Courts		4	2025-07-16 13:41:15.025284	2025-07-16 13:41:15.025284
4401002	4401	Self-employed		4	2025-07-16 13:41:15.027576	2025-07-16 13:41:15.027576
4402002	4402	Agriculture livelihoods		4	2025-07-16 13:41:15.031221	2025-07-16 13:41:15.031221
4402005	4402	Culture livelihoods		4	2025-07-16 13:41:15.034209	2025-07-16 13:41:15.034209
4402008	4402	Care livelihoods		4	2025-07-16 13:41:15.036775	2025-07-16 13:41:15.036775
4501003	4501	Hazard monitoring		4	2025-07-16 13:41:15.040725	2025-07-16 13:41:15.040725
4103001	4103	Supporting services		4	2025-07-16 13:41:15.003474	2025-07-16 13:41:15.003474
4103004	4103	Cultural services		4	2025-07-16 13:41:15.005634	2025-07-16 13:41:15.005634
4201004	4201	Livelihoods - production		4	2025-07-16 13:41:15.009929	2025-07-16 13:41:15.009929
4201006	4201	Human mobility		4	2025-07-16 13:41:15.012187	2025-07-16 13:41:15.012187
4202003	4202	Psychological abuse		4	2025-07-16 13:41:15.017688	2025-07-16 13:41:15.017688
4202005	4202	Harmful traditional practices		4	2025-07-16 13:41:15.020016	2025-07-16 13:41:15.020016
4301001	4301	Administration of the state		4	2025-07-16 13:41:15.021257	2025-07-16 13:41:15.021257
4302001	4302	Government		4	2025-07-16 13:41:15.022897	2025-07-16 13:41:15.022897
4304002	4304	Tribunals		4	2025-07-16 13:41:15.026361	2025-07-16 13:41:15.026361
4401003	4401	Gig workers/ Dependent contractor		4	2025-07-16 13:41:15.028979	2025-07-16 13:41:15.028979
4402003	4402	Service livelihoods		4	2025-07-16 13:41:15.03228	2025-07-16 13:41:15.03228
4402006	4402	Tourism livelihoods		4	2025-07-16 13:41:15.035135	2025-07-16 13:41:15.035135
4501001	4501	Disaster response		4	2025-07-16 13:41:15.037252	2025-07-16 13:41:15.037252
\.


--
-- TOC entry 6243 (class 0 OID 290418)
-- Dependencies: 259
-- Data for Name: sector_disaster_records_relation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sector_disaster_records_relation (api_import_id, id, sector_id, disaster_record_id, with_damage, damage_cost, damage_cost_currency, damage_recovery_cost, damage_recovery_cost_currency, with_disruption, with_losses, losses_cost, losses_cost_currency) FROM stdin;
\.


--
-- TOC entry 6245 (class 0 OID 290425)
-- Dependencies: 261
-- Data for Name: session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session (id, user_id, last_active_at, totp_authed) FROM stdin;
0db45c33-ce53-4416-9e74-896aaa11339a	1	2025-07-16 17:28:03.471	f
12dd2a40-904b-48bd-9ba0-40c6fff6849e	1	2025-07-16 18:46:06.672	f
\.


--
-- TOC entry 5760 (class 0 OID 289394)
-- Dependencies: 217
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- TOC entry 6246 (class 0 OID 290431)
-- Dependencies: 262
-- Data for Name: unit; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.unit (api_import_id, id, type, name) FROM stdin;
\.


--
-- TOC entry 6247 (class 0 OID 290438)
-- Dependencies: 263
-- Data for Name: user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."user" (id, role, first_name, last_name, email, password, email_verified, email_verification_code, email_verification_sent_at, email_verification_expires_at, invite_code, invite_sent_at, invite_expires_at, reset_password_token, reset_password_expires_at, totp_enabled, totp_secret, totp_secret_url, organization, hydromet_che_user, auth_type, updated_at, created_at) FROM stdin;
1	admin	Mario		mayandar@gmail.com	$2b$10$/24ntH4SE.dKSVWM5gERVeuwIe23ZBUl2PbVdsQk35j/njBo.akDO	t	288162	2025-07-16 17:13:52.632	2025-07-17 17:13:52.632		\N	2000-01-01 00:00:00		2000-01-01 00:00:00	f				f	form	2025-07-16 12:13:52.627118	2025-07-16 12:13:52.627118
\.


--
-- TOC entry 6263 (class 0 OID 0)
-- Dependencies: 222
-- Name: __drizzle_migrations___id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.__drizzle_migrations___id_seq', 1, false);


--
-- TOC entry 6264 (class 0 OID 0)
-- Dependencies: 225
-- Name: api_key_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.api_key_id_seq', 1, true);


--
-- TOC entry 6265 (class 0 OID 0)
-- Dependencies: 229
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categories_id_seq', 1, false);


--
-- TOC entry 6266 (class 0 OID 0)
-- Dependencies: 231
-- Name: country1_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.country1_id_seq', 1, false);


--
-- TOC entry 6267 (class 0 OID 0)
-- Dependencies: 235
-- Name: dev_example1_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dev_example1_id_seq', 1, false);


--
-- TOC entry 6268 (class 0 OID 0)
-- Dependencies: 241
-- Name: division_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.division_id_seq', 1, false);


--
-- TOC entry 6269 (class 0 OID 0)
-- Dependencies: 260
-- Name: sector_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sector_id_seq', 1, false);


--
-- TOC entry 6270 (class 0 OID 0)
-- Dependencies: 264
-- Name: user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_id_seq', 1, true);


--
-- TOC entry 5908 (class 2606 OID 290472)
-- Name: __drizzle_migrations__ __drizzle_migrations___pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.__drizzle_migrations__
    ADD CONSTRAINT __drizzle_migrations___pkey PRIMARY KEY (id);


--
-- TOC entry 5910 (class 2606 OID 290474)
-- Name: affected affected_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.affected
    ADD CONSTRAINT affected_pkey PRIMARY KEY (id);


--
-- TOC entry 5912 (class 2606 OID 290476)
-- Name: api_key api_key_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_key
    ADD CONSTRAINT api_key_pkey PRIMARY KEY (id);


--
-- TOC entry 5914 (class 2606 OID 290478)
-- Name: api_key api_key_secret_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_key
    ADD CONSTRAINT api_key_secret_unique UNIQUE (secret);


--
-- TOC entry 5916 (class 2606 OID 290480)
-- Name: asset asset_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5918 (class 2606 OID 290482)
-- Name: asset asset_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_pkey PRIMARY KEY (id);


--
-- TOC entry 5920 (class 2606 OID 290484)
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- TOC entry 5922 (class 2606 OID 290486)
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- TOC entry 5924 (class 2606 OID 290488)
-- Name: country1 country1_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.country1
    ADD CONSTRAINT country1_pkey PRIMARY KEY (id);


--
-- TOC entry 5926 (class 2606 OID 290490)
-- Name: damages damages_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5928 (class 2606 OID 290492)
-- Name: damages damages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_pkey PRIMARY KEY (id);


--
-- TOC entry 5930 (class 2606 OID 290494)
-- Name: deaths deaths_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deaths
    ADD CONSTRAINT deaths_pkey PRIMARY KEY (id);


--
-- TOC entry 5932 (class 2606 OID 290496)
-- Name: dev_example1 dev_example1_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dev_example1
    ADD CONSTRAINT dev_example1_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5934 (class 2606 OID 290498)
-- Name: dev_example1 dev_example1_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dev_example1
    ADD CONSTRAINT dev_example1_pkey PRIMARY KEY (id);


--
-- TOC entry 5936 (class 2606 OID 290500)
-- Name: disaster_event disaster_event_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_event
    ADD CONSTRAINT disaster_event_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5938 (class 2606 OID 290502)
-- Name: disaster_event disaster_event_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_event
    ADD CONSTRAINT disaster_event_pkey PRIMARY KEY (id);


--
-- TOC entry 5940 (class 2606 OID 290504)
-- Name: disaster_records disaster_records_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_records
    ADD CONSTRAINT disaster_records_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5942 (class 2606 OID 290506)
-- Name: disaster_records disaster_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_records
    ADD CONSTRAINT disaster_records_pkey PRIMARY KEY (id);


--
-- TOC entry 5944 (class 2606 OID 290508)
-- Name: displaced displaced_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.displaced
    ADD CONSTRAINT displaced_pkey PRIMARY KEY (id);


--
-- TOC entry 5946 (class 2606 OID 290510)
-- Name: disruption disruption_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disruption
    ADD CONSTRAINT disruption_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5948 (class 2606 OID 290512)
-- Name: disruption disruption_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disruption
    ADD CONSTRAINT disruption_pkey PRIMARY KEY (id);


--
-- TOC entry 5952 (class 2606 OID 290514)
-- Name: division division_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.division
    ADD CONSTRAINT division_import_id_unique UNIQUE (import_id);


--
-- TOC entry 5955 (class 2606 OID 290516)
-- Name: division division_national_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.division
    ADD CONSTRAINT division_national_id_unique UNIQUE (national_id);


--
-- TOC entry 5957 (class 2606 OID 290518)
-- Name: division division_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.division
    ADD CONSTRAINT division_pkey PRIMARY KEY (id);


--
-- TOC entry 5960 (class 2606 OID 290520)
-- Name: dts_system_info dts_system_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dts_system_info
    ADD CONSTRAINT dts_system_info_pkey PRIMARY KEY (id);


--
-- TOC entry 5962 (class 2606 OID 290522)
-- Name: event event_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- TOC entry 5964 (class 2606 OID 290524)
-- Name: hazardous_event hazardous_event_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hazardous_event
    ADD CONSTRAINT hazardous_event_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5966 (class 2606 OID 290526)
-- Name: hazardous_event hazardous_event_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hazardous_event
    ADD CONSTRAINT hazardous_event_pkey PRIMARY KEY (id);


--
-- TOC entry 5968 (class 2606 OID 290528)
-- Name: hip_class hip_class_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hip_class
    ADD CONSTRAINT hip_class_pkey PRIMARY KEY (id);


--
-- TOC entry 5970 (class 2606 OID 290530)
-- Name: hip_cluster hip_cluster_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hip_cluster
    ADD CONSTRAINT hip_cluster_pkey PRIMARY KEY (id);


--
-- TOC entry 5972 (class 2606 OID 290532)
-- Name: hip_hazard hip_hazard_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hip_hazard
    ADD CONSTRAINT hip_hazard_pkey PRIMARY KEY (id);


--
-- TOC entry 5974 (class 2606 OID 290534)
-- Name: human_category_presence human_category_presence_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.human_category_presence
    ADD CONSTRAINT human_category_presence_pkey PRIMARY KEY (id);


--
-- TOC entry 5976 (class 2606 OID 290536)
-- Name: human_dsg human_dsg_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.human_dsg
    ADD CONSTRAINT human_dsg_pkey PRIMARY KEY (id);


--
-- TOC entry 5978 (class 2606 OID 290538)
-- Name: injured injured_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.injured
    ADD CONSTRAINT injured_pkey PRIMARY KEY (id);


--
-- TOC entry 5980 (class 2606 OID 290540)
-- Name: instance_system_settings instance_system_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instance_system_settings
    ADD CONSTRAINT instance_system_settings_pkey PRIMARY KEY (id);


--
-- TOC entry 5982 (class 2606 OID 290542)
-- Name: losses losses_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.losses
    ADD CONSTRAINT losses_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5984 (class 2606 OID 290544)
-- Name: losses losses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.losses
    ADD CONSTRAINT losses_pkey PRIMARY KEY (id);


--
-- TOC entry 5986 (class 2606 OID 290546)
-- Name: measure measure_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.measure
    ADD CONSTRAINT measure_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5988 (class 2606 OID 290548)
-- Name: measure measure_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.measure
    ADD CONSTRAINT measure_pkey PRIMARY KEY (id);


--
-- TOC entry 5990 (class 2606 OID 290550)
-- Name: missing missing_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.missing
    ADD CONSTRAINT missing_pkey PRIMARY KEY (id);


--
-- TOC entry 5992 (class 2606 OID 290552)
-- Name: noneco_losses noneco_losses_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.noneco_losses
    ADD CONSTRAINT noneco_losses_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 5994 (class 2606 OID 290554)
-- Name: noneco_losses noneco_losses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.noneco_losses
    ADD CONSTRAINT noneco_losses_pkey PRIMARY KEY (id);


--
-- TOC entry 5996 (class 2606 OID 290556)
-- Name: noneco_losses nonecolosses_sectorIdx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.noneco_losses
    ADD CONSTRAINT "nonecolosses_sectorIdx" UNIQUE (disaster_record_id, category_id);


--
-- TOC entry 6000 (class 2606 OID 290558)
-- Name: sector_disaster_records_relation sector_disaster_records_relation_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sector_disaster_records_relation
    ADD CONSTRAINT sector_disaster_records_relation_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 6002 (class 2606 OID 290560)
-- Name: sector_disaster_records_relation sector_disaster_records_relation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sector_disaster_records_relation
    ADD CONSTRAINT sector_disaster_records_relation_pkey PRIMARY KEY (id);


--
-- TOC entry 6004 (class 2606 OID 290562)
-- Name: sector_disaster_records_relation sector_disaster_records_relation_sector_id_disaster_record_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sector_disaster_records_relation
    ADD CONSTRAINT sector_disaster_records_relation_sector_id_disaster_record_id UNIQUE (sector_id, disaster_record_id);


--
-- TOC entry 5998 (class 2606 OID 290564)
-- Name: sector sector_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sector
    ADD CONSTRAINT sector_pkey PRIMARY KEY (id);


--
-- TOC entry 6006 (class 2606 OID 290566)
-- Name: session session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_pkey PRIMARY KEY (id);


--
-- TOC entry 6008 (class 2606 OID 290568)
-- Name: unit unit_api_import_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_api_import_id_unique UNIQUE (api_import_id);


--
-- TOC entry 6010 (class 2606 OID 290570)
-- Name: unit unit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_pkey PRIMARY KEY (id);


--
-- TOC entry 6012 (class 2606 OID 290572)
-- Name: user user_email_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_email_unique UNIQUE (email);


--
-- TOC entry 6014 (class 2606 OID 290574)
-- Name: user user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- TOC entry 5949 (class 1259 OID 290575)
-- Name: division_bbox_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX division_bbox_idx ON public.division USING gist (bbox);


--
-- TOC entry 5950 (class 1259 OID 290576)
-- Name: division_geom_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX division_geom_idx ON public.division USING gist (geom);


--
-- TOC entry 5953 (class 1259 OID 290577)
-- Name: division_level_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX division_level_idx ON public.division USING btree (level);


--
-- TOC entry 5958 (class 1259 OID 290578)
-- Name: parent_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX parent_idx ON public.division USING btree (parent_id);


--
-- TOC entry 6015 (class 2606 OID 290579)
-- Name: affected affected_dsg_id_human_dsg_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.affected
    ADD CONSTRAINT affected_dsg_id_human_dsg_id_fk FOREIGN KEY (dsg_id) REFERENCES public.human_dsg(id);


--
-- TOC entry 6016 (class 2606 OID 290584)
-- Name: api_key api_key_user_id_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_key
    ADD CONSTRAINT api_key_user_id_user_id_fk FOREIGN KEY (user_id) REFERENCES public."user"(id);


--
-- TOC entry 6017 (class 2606 OID 290589)
-- Name: audit_logs audit_logs_user_id_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_user_id_fk FOREIGN KEY (user_id) REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 6018 (class 2606 OID 290594)
-- Name: categories categories_parent_id_categories_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_categories_id_fk FOREIGN KEY (parent_id) REFERENCES public.categories(id);


--
-- TOC entry 6019 (class 2606 OID 290599)
-- Name: damages damages_asset_id_asset_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_asset_id_asset_id_fk FOREIGN KEY (asset_id) REFERENCES public.asset(id);


--
-- TOC entry 6020 (class 2606 OID 290604)
-- Name: damages damages_record_id_disaster_records_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_record_id_disaster_records_id_fk FOREIGN KEY (record_id) REFERENCES public.disaster_records(id);


--
-- TOC entry 6021 (class 2606 OID 290609)
-- Name: damages damages_sector_id_sector_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_sector_id_sector_id_fk FOREIGN KEY (sector_id) REFERENCES public.sector(id);


--
-- TOC entry 6022 (class 2606 OID 290614)
-- Name: deaths deaths_dsg_id_human_dsg_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deaths
    ADD CONSTRAINT deaths_dsg_id_human_dsg_id_fk FOREIGN KEY (dsg_id) REFERENCES public.human_dsg(id);


--
-- TOC entry 6023 (class 2606 OID 290619)
-- Name: disaster_event disaster_event_disaster_event_id_disaster_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_event
    ADD CONSTRAINT disaster_event_disaster_event_id_disaster_event_id_fk FOREIGN KEY (disaster_event_id) REFERENCES public.disaster_event(id);


--
-- TOC entry 6024 (class 2606 OID 290624)
-- Name: disaster_event disaster_event_hazardous_event_id_hazardous_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_event
    ADD CONSTRAINT disaster_event_hazardous_event_id_hazardous_event_id_fk FOREIGN KEY (hazardous_event_id) REFERENCES public.hazardous_event(id);


--
-- TOC entry 6025 (class 2606 OID 290629)
-- Name: disaster_event disaster_event_hip_cluster_id_hip_cluster_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_event
    ADD CONSTRAINT disaster_event_hip_cluster_id_hip_cluster_id_fk FOREIGN KEY (hip_cluster_id) REFERENCES public.hip_cluster(id);


--
-- TOC entry 6026 (class 2606 OID 290634)
-- Name: disaster_event disaster_event_hip_hazard_id_hip_hazard_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_event
    ADD CONSTRAINT disaster_event_hip_hazard_id_hip_hazard_id_fk FOREIGN KEY (hip_hazard_id) REFERENCES public.hip_hazard(id);


--
-- TOC entry 6027 (class 2606 OID 290639)
-- Name: disaster_event disaster_event_hip_type_id_hip_class_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_event
    ADD CONSTRAINT disaster_event_hip_type_id_hip_class_id_fk FOREIGN KEY (hip_type_id) REFERENCES public.hip_class(id);


--
-- TOC entry 6028 (class 2606 OID 290644)
-- Name: disaster_event disaster_event_id_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_event
    ADD CONSTRAINT disaster_event_id_event_id_fk FOREIGN KEY (id) REFERENCES public.event(id);


--
-- TOC entry 6029 (class 2606 OID 290649)
-- Name: disaster_records disaster_records_disaster_event_id_disaster_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_records
    ADD CONSTRAINT disaster_records_disaster_event_id_disaster_event_id_fk FOREIGN KEY (disaster_event_id) REFERENCES public.disaster_event(id);


--
-- TOC entry 6030 (class 2606 OID 290654)
-- Name: disaster_records disaster_records_hip_cluster_id_hip_cluster_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_records
    ADD CONSTRAINT disaster_records_hip_cluster_id_hip_cluster_id_fk FOREIGN KEY (hip_cluster_id) REFERENCES public.hip_cluster(id);


--
-- TOC entry 6031 (class 2606 OID 290659)
-- Name: disaster_records disaster_records_hip_hazard_id_hip_hazard_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_records
    ADD CONSTRAINT disaster_records_hip_hazard_id_hip_hazard_id_fk FOREIGN KEY (hip_hazard_id) REFERENCES public.hip_hazard(id);


--
-- TOC entry 6032 (class 2606 OID 290664)
-- Name: disaster_records disaster_records_hip_type_id_hip_class_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disaster_records
    ADD CONSTRAINT disaster_records_hip_type_id_hip_class_id_fk FOREIGN KEY (hip_type_id) REFERENCES public.hip_class(id);


--
-- TOC entry 6033 (class 2606 OID 290669)
-- Name: displaced displaced_dsg_id_human_dsg_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.displaced
    ADD CONSTRAINT displaced_dsg_id_human_dsg_id_fk FOREIGN KEY (dsg_id) REFERENCES public.human_dsg(id);


--
-- TOC entry 6034 (class 2606 OID 290674)
-- Name: disruption disruption_record_id_disaster_records_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disruption
    ADD CONSTRAINT disruption_record_id_disaster_records_id_fk FOREIGN KEY (record_id) REFERENCES public.disaster_records(id);


--
-- TOC entry 6035 (class 2606 OID 290679)
-- Name: disruption disruption_sector_id_sector_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disruption
    ADD CONSTRAINT disruption_sector_id_sector_id_fk FOREIGN KEY (sector_id) REFERENCES public.sector(id);


--
-- TOC entry 6036 (class 2606 OID 290684)
-- Name: division division_parent_id_division_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.division
    ADD CONSTRAINT division_parent_id_division_id_fk FOREIGN KEY (parent_id) REFERENCES public.division(id);


--
-- TOC entry 6037 (class 2606 OID 290689)
-- Name: event_relationship event_relationship_child_id_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_relationship
    ADD CONSTRAINT event_relationship_child_id_event_id_fk FOREIGN KEY (child_id) REFERENCES public.event(id);


--
-- TOC entry 6038 (class 2606 OID 290694)
-- Name: event_relationship event_relationship_parent_id_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_relationship
    ADD CONSTRAINT event_relationship_parent_id_event_id_fk FOREIGN KEY (parent_id) REFERENCES public.event(id);


--
-- TOC entry 6039 (class 2606 OID 290699)
-- Name: hazardous_event hazardous_event_hip_cluster_id_hip_cluster_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hazardous_event
    ADD CONSTRAINT hazardous_event_hip_cluster_id_hip_cluster_id_fk FOREIGN KEY (hip_cluster_id) REFERENCES public.hip_cluster(id);


--
-- TOC entry 6040 (class 2606 OID 290704)
-- Name: hazardous_event hazardous_event_hip_hazard_id_hip_hazard_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hazardous_event
    ADD CONSTRAINT hazardous_event_hip_hazard_id_hip_hazard_id_fk FOREIGN KEY (hip_hazard_id) REFERENCES public.hip_hazard(id);


--
-- TOC entry 6041 (class 2606 OID 290709)
-- Name: hazardous_event hazardous_event_hip_type_id_hip_class_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hazardous_event
    ADD CONSTRAINT hazardous_event_hip_type_id_hip_class_id_fk FOREIGN KEY (hip_type_id) REFERENCES public.hip_class(id);


--
-- TOC entry 6042 (class 2606 OID 290714)
-- Name: hazardous_event hazardous_event_id_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hazardous_event
    ADD CONSTRAINT hazardous_event_id_event_id_fk FOREIGN KEY (id) REFERENCES public.event(id);


--
-- TOC entry 6043 (class 2606 OID 290719)
-- Name: hip_cluster hip_cluster_type_id_hip_class_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hip_cluster
    ADD CONSTRAINT hip_cluster_type_id_hip_class_id_fk FOREIGN KEY (type_id) REFERENCES public.hip_class(id);


--
-- TOC entry 6044 (class 2606 OID 290724)
-- Name: hip_hazard hip_hazard_cluster_id_hip_cluster_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hip_hazard
    ADD CONSTRAINT hip_hazard_cluster_id_hip_cluster_id_fk FOREIGN KEY (cluster_id) REFERENCES public.hip_cluster(id);


--
-- TOC entry 6045 (class 2606 OID 290729)
-- Name: human_category_presence human_category_presence_record_id_disaster_records_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.human_category_presence
    ADD CONSTRAINT human_category_presence_record_id_disaster_records_id_fk FOREIGN KEY (record_id) REFERENCES public.disaster_records(id);


--
-- TOC entry 6046 (class 2606 OID 290734)
-- Name: human_dsg human_dsg_record_id_disaster_records_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.human_dsg
    ADD CONSTRAINT human_dsg_record_id_disaster_records_id_fk FOREIGN KEY (record_id) REFERENCES public.disaster_records(id);


--
-- TOC entry 6047 (class 2606 OID 290739)
-- Name: injured injured_dsg_id_human_dsg_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.injured
    ADD CONSTRAINT injured_dsg_id_human_dsg_id_fk FOREIGN KEY (dsg_id) REFERENCES public.human_dsg(id);


--
-- TOC entry 6048 (class 2606 OID 290744)
-- Name: losses losses_record_id_disaster_records_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.losses
    ADD CONSTRAINT losses_record_id_disaster_records_id_fk FOREIGN KEY (record_id) REFERENCES public.disaster_records(id);


--
-- TOC entry 6049 (class 2606 OID 290749)
-- Name: losses losses_sector_id_sector_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.losses
    ADD CONSTRAINT losses_sector_id_sector_id_fk FOREIGN KEY (sector_id) REFERENCES public.sector(id);


--
-- TOC entry 6050 (class 2606 OID 290754)
-- Name: missing missing_dsg_id_human_dsg_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.missing
    ADD CONSTRAINT missing_dsg_id_human_dsg_id_fk FOREIGN KEY (dsg_id) REFERENCES public.human_dsg(id);


--
-- TOC entry 6051 (class 2606 OID 290759)
-- Name: noneco_losses noneco_losses_category_id_categories_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.noneco_losses
    ADD CONSTRAINT noneco_losses_category_id_categories_id_fk FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- TOC entry 6052 (class 2606 OID 290764)
-- Name: noneco_losses noneco_losses_disaster_record_id_disaster_records_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.noneco_losses
    ADD CONSTRAINT noneco_losses_disaster_record_id_disaster_records_id_fk FOREIGN KEY (disaster_record_id) REFERENCES public.disaster_records(id);


--
-- TOC entry 6054 (class 2606 OID 290769)
-- Name: sector_disaster_records_relation sector_disaster_records_relation_disaster_record_id_disaster_re; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sector_disaster_records_relation
    ADD CONSTRAINT sector_disaster_records_relation_disaster_record_id_disaster_re FOREIGN KEY (disaster_record_id) REFERENCES public.disaster_records(id);


--
-- TOC entry 6055 (class 2606 OID 290774)
-- Name: sector_disaster_records_relation sector_disaster_records_relation_sector_id_sector_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sector_disaster_records_relation
    ADD CONSTRAINT sector_disaster_records_relation_sector_id_sector_id_fk FOREIGN KEY (sector_id) REFERENCES public.sector(id);


--
-- TOC entry 6053 (class 2606 OID 290779)
-- Name: sector sector_parent_id_sector_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sector
    ADD CONSTRAINT sector_parent_id_sector_id_fk FOREIGN KEY (parent_id) REFERENCES public.sector(id);


--
-- TOC entry 6056 (class 2606 OID 290784)
-- Name: session session_user_id_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_user_id_user_id_fk FOREIGN KEY (user_id) REFERENCES public."user"(id);


-- Completed on 2025-07-16 14:24:42

--
-- PostgreSQL database dump complete
--

