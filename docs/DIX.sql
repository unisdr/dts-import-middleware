CREATE TYPE "rec_status" AS ENUM (
  'published',
  'draft',
  'revision'
);

CREATE TYPE "eff_type" AS ENUM (
  'deaths',
  'missing',
  'injured',
  'indirectaffected',
  'directaffected',
  'evacuated',
  'relocated',
  'otherhuman'
);

CREATE TABLE "records" (
  "reg_id" varchar NOT NULL,
  "rec_uuid" varchar PRIMARY KEY,
  "serial" varchar NOT NULL,
  "year" integer NOT NULL,
  "month" integer,
  "day" integer,
  "duration" integer,
  "eff_econusd" real,
  "eff_econlcu" real,
  "eff_other" text,
  "eff_withothersector" boolean,
  "card_usereff" text,
  "card_version" varchar NOT NULL,
  "sources" varchar,
  "status" rec_status,
  "created" timestamp,
  "updated" timestamp
);

CREATE TABLE "damages" (
  "asset_id" varchar,
  "record_id" varchar,
  "total" real,
  "destroyed" real,
  "damaged" real,
  "economic" real,
  "withanyaff" boolean,
  PRIMARY KEY ("asset_id", "record_id")
);

CREATE TABLE "disruptions" (
  "record_id" varchar,
  "sector_id" varchar,
  "disruptnum" integer NOT NULL,
  PRIMARY KEY ("record_id", "sector_id")
);

CREATE TABLE "human" (
  "record_id" varchar,
  "humaneff_id" varchar,
  "value" integer,
  "withaffect" boolean,
  PRIMARY KEY ("record_id", "humaneff_id")
);

CREATE TABLE "humaneff" (
  "id" varchar PRIMARY KEY,
  "description" text,
  "type" eff_type,
  "codeqt" varchar,
  "codeql" varchar
);

CREATE TABLE "assets" (
  "sector_id" varchar,
  "id" varchar PRIMARY KEY,
  "name" varchar,
  "description" text,
  "measure" varchar,
  "parent_id" varchar,
  "codeqt_tot" varchar,
  "codeqt_dst" varchar,
  "codeqt_dmg" varchar,
  "codeqt_eco" varchar
);

CREATE TABLE "regeffects" (
  "reg_id" varchar,
  "humaneff_id" varchar,
  "sector_id" varchar,
  "asset_id" varchar
);

CREATE TABLE "sectors" (
  "id" varchar PRIMARY KEY,
  "name" varchar NOT NULL,
  "description" text,
  "parent_id" varchar,
  "codeql" varchar
);

CREATE TABLE "region" (
  "region_id" varchar PRIMARY KEY,
  "parent_reg" varchar,
  "name" varchar NOT NULL,
  "description" text,
  "lang" varchar(2),
  "sources" varchar,
  "tags" text,
  "export_url" varchar,
  "export_apikey" varchar,
  "region_rules" text,
  "created" timestamp,
  "updated" timestamp
);

CREATE TABLE "transfer_log" (
  "id" serial,
  "reg_id" varchar NOT NULL,
  "version" varchar,
  "lastupdate" timestamp,
  "recordnumber" integer,
  "log" text
);

CREATE TABLE "layers" (
  "reg_id" varchar NOT NULL,
  "lay_id" varchar PRIMARY KEY,
  "label" varchar,
  "name" varchar,
  "description" text,
  "source" varchar,
  "year_ini" integer,
  "year_end" integer,
  "laytype_id" varchar NOT NULL,
  "level" integer
);

CREATE TABLE "layer_type" (
  "id" varchar PRIMARY KEY,
  "laytype_name" varchar,
  "laytype_desc" varchar,
  "url" varchar
);

CREATE TABLE "layer_data" (
  "lay_id" varchar NOT NULL,
  "guuid" varchar PRIMARY KEY,
  "ownid" varchar,
  "label" varchar,
  "code" varchar,
  "name" varchar,
  "guuid_parent" varchar,
  "geom" geometry
);

CREATE TABLE "geodata" (
  "id" serial PRIMARY KEY,
  "geogra_id" varchar,
  "geocontext_id" varchar,
  "class" varchar,
  "type" varchar,
  "year_ini" integer,
  "year_end" integer,
  "value1" integer,
  "value2" real,
  "value3" real
);

CREATE TABLE "geocontext" (
  "id" varchar PRIMARY KEY,
  "contextname" varchar,
  "description" text,
  "source" varchar,
  "regions" text,
  "layers" text,
  "sectors" text
);

CREATE TABLE "georecord" (
  "record_id" varchar,
  "geogra_id" varchar,
  "laytype_id" varchar,
  "location" text,
  PRIMARY KEY ("record_id", "geogra_id")
);

CREATE TABLE "catalogue" (
  "id" varchar PRIMARY KEY,
  "name" varchar,
  "description" text,
  "source" varchar,
  "owner" varchar
);

CREATE TABLE "groups" (
  "cat_id" varchar NOT NULL,
  "id" varchar PRIMARY KEY,
  "code" varchar,
  "name" varchar,
  "fullname" varchar,
  "description" text,
  "parent_id" varchar,
  "level" integer,
  "join_rules" varchar,
  "reference" varchar
);

CREATE TABLE "groupsrecord" (
  "record_id" varchar,
  "grp_id" varchar,
  "grp_info" text,
  PRIMARY KEY ("record_id", "grp_id")
);

COMMENT ON TABLE "records" IS ':: Disasters Records';

COMMENT ON COLUMN "records"."eff_econusd" IS 'The equivalent in dollars (US$) of the value of losses in local currency, according to the exchange rate on the date of the disaster. This figure is useful for comparative evaluations between databases.';

COMMENT ON COLUMN "records"."eff_econlcu" IS 'Sum of losses directly caused by the disaster in local currency.';

COMMENT ON COLUMN "records"."eff_other" IS 'A description of other losses not included in the fields of the basic record. For example: religious buildings and monuments, architectural or cultural heritage buildings, theatres and public installations, public administration buildings relating to banks, commerce and tourism; vehicles or buses lost, bridges.';

COMMENT ON COLUMN "records"."eff_withothersector" IS 'It relates to damages which do not correspond to any of the fields in the basic record.';

COMMENT ON COLUMN "records"."card_usereff" IS 'Other userdefined effects';

COMMENT ON COLUMN "records"."card_version" IS 'md5 generated using simplified datacard used to compare';

COMMENT ON TABLE "damages" IS ':: # of deaths or $ damages';

COMMENT ON COLUMN "damages"."total" IS 'Total damages or destroyed';

COMMENT ON COLUMN "damages"."destroyed" IS 'levelled, buried, collapsed or damaged to the extent that they are no longer habitable/ usable. ';

COMMENT ON COLUMN "damages"."damaged" IS 'minor damage, not structural or architectural, which may continue being lived in, although they may require some repair or cleaning.';

COMMENT ON TABLE "disruptions" IS 'Relation Disruptions and Records';

COMMENT ON TABLE "human" IS 'Relation Human and Records';

COMMENT ON TABLE "assets" IS ':: Crops, Houses';

COMMENT ON COLUMN "assets"."measure" IS 'units, hectares, currency, kms';

COMMENT ON TABLE "sectors" IS ':: Agriculture,';

COMMENT ON COLUMN "region"."region_rules" IS 'Native admin structure: lev0- code, lev1- code, etc';

COMMENT ON TABLE "layers" IS 'Like levels:: 0: Country, 1: Departamento, 2: municipio, 3: ... ';

COMMENT ON TABLE "layer_data" IS 'postgis table: subnational shapefiles, OSM DB';

COMMENT ON COLUMN "layer_data"."ownid" IS 'Original ID';

COMMENT ON COLUMN "layer_data"."geom" IS 'GEOMETRY(Geometry, 4326)';

COMMENT ON TABLE "geodata" IS 'Contextual data';

COMMENT ON TABLE "geocontext" IS 'Contextual Geographical info';

COMMENT ON TABLE "georecord" IS 'Relation GeoData and Records';

COMMENT ON COLUMN "georecord"."location" IS 'card_geolocation text';

COMMENT ON TABLE "catalogue" IS 'candidate to Hazardous events amoung others';

COMMENT ON TABLE "groups" IS 'HIPs, others';

COMMENT ON TABLE "groupsrecord" IS 'Relation Groups - Records';

ALTER TABLE "regeffects" ADD FOREIGN KEY ("reg_id") REFERENCES "region" ("region_id");

ALTER TABLE "regeffects" ADD FOREIGN KEY ("humaneff_id") REFERENCES "humaneff" ("id");

ALTER TABLE "regeffects" ADD FOREIGN KEY ("asset_id") REFERENCES "assets" ("id");

ALTER TABLE "regeffects" ADD FOREIGN KEY ("sector_id") REFERENCES "sectors" ("id");

ALTER TABLE "groups" ADD FOREIGN KEY ("cat_id") REFERENCES "catalogue" ("id");

ALTER TABLE "groups" ADD FOREIGN KEY ("parent_id") REFERENCES "groups" ("id");

ALTER TABLE "groupsrecord" ADD FOREIGN KEY ("record_id") REFERENCES "records" ("rec_uuid");

ALTER TABLE "groupsrecord" ADD FOREIGN KEY ("grp_id") REFERENCES "groups" ("id");

ALTER TABLE "human" ADD FOREIGN KEY ("humaneff_id") REFERENCES "humaneff" ("id");

ALTER TABLE "human" ADD FOREIGN KEY ("record_id") REFERENCES "records" ("rec_uuid");

ALTER TABLE "transfer_log" ADD FOREIGN KEY ("reg_id") REFERENCES "region" ("region_id");

ALTER TABLE "layers" ADD FOREIGN KEY ("reg_id") REFERENCES "region" ("region_id");

ALTER TABLE "georecord" ADD FOREIGN KEY ("record_id") REFERENCES "records" ("rec_uuid");

ALTER TABLE "georecord" ADD FOREIGN KEY ("geogra_id") REFERENCES "layer_data" ("guuid");

ALTER TABLE "geodata" ADD FOREIGN KEY ("geogra_id") REFERENCES "layer_data" ("guuid");

ALTER TABLE "geodata" ADD FOREIGN KEY ("geocontext_id") REFERENCES "geocontext" ("id");

ALTER TABLE "layer_data" ADD FOREIGN KEY ("guuid_parent") REFERENCES "layer_data" ("guuid");

ALTER TABLE "damages" ADD FOREIGN KEY ("record_id") REFERENCES "records" ("rec_uuid");

ALTER TABLE "disruptions" ADD FOREIGN KEY ("record_id") REFERENCES "records" ("rec_uuid");

ALTER TABLE "records" ADD FOREIGN KEY ("reg_id") REFERENCES "region" ("region_id");

ALTER TABLE "region" ADD FOREIGN KEY ("parent_reg") REFERENCES "region" ("region_id");

ALTER TABLE "damages" ADD FOREIGN KEY ("asset_id") REFERENCES "assets" ("id");

ALTER TABLE "disruptions" ADD FOREIGN KEY ("sector_id") REFERENCES "sectors" ("id");

ALTER TABLE "assets" ADD FOREIGN KEY ("parent_id") REFERENCES "assets" ("id");

ALTER TABLE "assets" ADD FOREIGN KEY ("sector_id") REFERENCES "sectors" ("id");

ALTER TABLE "sectors" ADD FOREIGN KEY ("parent_id") REFERENCES "sectors" ("id");

ALTER TABLE "layer_data" ADD FOREIGN KEY ("lay_id") REFERENCES "layers" ("lay_id");

ALTER TABLE "layers" ADD FOREIGN KEY ("laytype_id") REFERENCES "layer_type" ("id");

ALTER TABLE "georecord" ADD FOREIGN KEY ("laytype_id") REFERENCES "layer_type" ("id");
