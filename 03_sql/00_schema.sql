-- Global Job Market Compensation Analysis — MySQL Schema
-- Run this FIRST, before loading data or running business_queries.sql

CREATE DATABASE IF NOT EXISTS job_market_analytics;
USE job_market_analytics;

DROP TABLE IF EXISTS job_market;

CREATE TABLE job_market (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    country              VARCHAR(50),
    city                 VARCHAR(50),
    occupation           VARCHAR(50),
    field                VARCHAR(50),
    years_of_experience  INT,
    salary               INT,
    employment_type      VARCHAR(30),
    education_level      VARCHAR(30),
    gender               VARCHAR(20),
    company_size         VARCHAR(20),
    year                 INT,
    month                INT,
    salary_outlier_flag  TINYINT(1),
    INDEX idx_country (country),
    INDEX idx_occupation (occupation)
);

-- After this, load job_market_export.csv into this table (see LOCAL_SETUP.md),
-- then run business_queries.sql from the sql/ folder.
