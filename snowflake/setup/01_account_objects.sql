/*
  One-time account setup for the Olist warehouse project.
  Idempotent — safe to re-run; uses CREATE OR REPLACE / IF NOT EXISTS.

  Run from a role with ACCOUNTADMIN (the trial default user has it).

      snow sql -f snowflake/setup/01_account_objects.sql
*/

USE ROLE ACCOUNTADMIN;

-- Three warehouses, sized for what they actually do.
-- LOAD_WH:    big enough to land 100MB in a few seconds, then auto-suspend.
-- XFORM_WH:   what dbt runs on; the SQL is non-trivial so XS would thrash.
-- ANALYST_WH: cheapest, what ad-hoc queries hit. Caches result reuse aggressively.

CREATE WAREHOUSE IF NOT EXISTS LOAD_WH
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Ingest from external stage into RAW';

CREATE WAREHOUSE IF NOT EXISTS XFORM_WH
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'dbt transformations from STG to MARTS';

CREATE WAREHOUSE IF NOT EXISTS ANALYST_WH
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 60
    COMMENT = 'Ad-hoc analyst queries; statement timeout prevents runaways';

-- Database + three schemas. Splitting RAW / STG / MARTS makes role
-- grants and lineage obvious.

CREATE DATABASE IF NOT EXISTS OLIST
    COMMENT = 'Olist Brazilian e-commerce — analytics warehouse';

USE DATABASE OLIST;

CREATE SCHEMA IF NOT EXISTS RAW    COMMENT = 'Untouched landing tables — exact CSV shape';
CREATE SCHEMA IF NOT EXISTS STG    COMMENT = 'Renamed/cast/cleaned, one model per source';
CREATE SCHEMA IF NOT EXISTS MARTS  COMMENT = 'Star schema — analyst-facing';

-- Internal stage where the loader PUTs CSVs before COPY INTO.
CREATE STAGE IF NOT EXISTS RAW.OLIST_STAGE
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = ('', 'NA'))
    COMMENT = 'Landing stage for the 8 Olist CSVs';

-- Role with the right least-privilege set for portfolio work.
CREATE ROLE IF NOT EXISTS WAREHOUSE_DEV
    COMMENT = 'Developer role for the Olist project';

GRANT USAGE  ON DATABASE OLIST           TO ROLE WAREHOUSE_DEV;
GRANT USAGE  ON ALL SCHEMAS IN DATABASE OLIST TO ROLE WAREHOUSE_DEV;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA OLIST.RAW   TO ROLE WAREHOUSE_DEV;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA OLIST.STG   TO ROLE WAREHOUSE_DEV;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA OLIST.MARTS TO ROLE WAREHOUSE_DEV;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN DATABASE OLIST TO ROLE WAREHOUSE_DEV;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN DATABASE OLIST TO ROLE WAREHOUSE_DEV;
GRANT USAGE ON WAREHOUSE LOAD_WH    TO ROLE WAREHOUSE_DEV;
GRANT USAGE ON WAREHOUSE XFORM_WH   TO ROLE WAREHOUSE_DEV;
GRANT USAGE ON WAREHOUSE ANALYST_WH TO ROLE WAREHOUSE_DEV;

-- Grant the role to the user running this script.
-- Note: GRANT ROLE does not accept IDENTIFIER(CURRENT_USER()); set the
-- target user explicitly. Replace NATHANAELHUB with your username, or
-- run separately: snow sql -q "GRANT ROLE WAREHOUSE_DEV TO USER <you>;"
SET grantee = CURRENT_USER();
GRANT ROLE WAREHOUSE_DEV TO USER IDENTIFIER($grantee);

-- Useful queries that prove setup worked.
SELECT 'setup complete' AS status,
       CURRENT_ACCOUNT() AS account,
       CURRENT_WAREHOUSE() AS current_wh,
       CURRENT_DATABASE() AS db;

SHOW SCHEMAS IN DATABASE OLIST;
SHOW WAREHOUSES;
