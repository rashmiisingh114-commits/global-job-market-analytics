-- ============================================================================
-- Global Job Market Compensation Analysis — SQL Business Query Bank
-- Database: MySQL 8.0
-- Table: job_market_analytics.job_market (499,972 rows, loaded from Phase 3's
--         cleaned dataset — same source as every Python notebook in this project)
-- ============================================================================

USE job_market_analytics;

-- ----------------------------------------------------------------------------
-- Q1. Top 3 highest-paying occupations per country (RANKING FUNCTION + CTE)
-- Business question: for a comp team benchmarking by country, which roles
-- command the premium in each market?
-- ----------------------------------------------------------------------------
WITH occupation_country_avg AS (
    SELECT
        country,
        occupation,
        ROUND(AVG(salary), 0) AS avg_salary,
        COUNT(*) AS n_records
    FROM job_market
    GROUP BY country, occupation
),
ranked AS (
    SELECT
        country,
        occupation,
        avg_salary,
        n_records,
        RANK() OVER (PARTITION BY country ORDER BY avg_salary DESC) AS rank_in_country
    FROM occupation_country_avg
)
SELECT country, occupation, avg_salary, n_records, rank_in_country
FROM ranked
WHERE rank_in_country <= 3
ORDER BY country, rank_in_country;


-- ----------------------------------------------------------------------------
-- Q2. Salary band classification via CASE WHEN, with distribution counts
-- Business question: how many employees fall into each pay tier, and what's
-- their average experience? (Mirrors Phase 4's Python-side salary_band feature,
-- built independently here in pure SQL.)
-- ----------------------------------------------------------------------------
-- Cutoffs below are the EXACT quartile boundaries from Phase 4's Python pd.qcut(salary, q=4)
-- (Low: 12,000-142,798 | Mid: 142,799-200,229 | High: 200,230-267,816 | Very High: 267,817-370,000),
-- not rounded estimates -- this guarantees the SQL-side band matches the Python-side
-- salary_band feature exactly, row for row.
SELECT
    CASE
        WHEN salary <= 142798 THEN 'Low'
        WHEN salary <= 200229 THEN 'Mid'
        WHEN salary <= 267816 THEN 'High'
        ELSE 'Very High'
    END AS salary_band,
    COUNT(*) AS n_employees,
    ROUND(AVG(years_of_experience), 1) AS avg_experience,
    ROUND(AVG(salary), 0) AS avg_salary
FROM job_market
GROUP BY salary_band
ORDER BY avg_salary;


-- ----------------------------------------------------------------------------
-- Q3. Countries with above-global-average salary (SUBQUERY)
-- Business question: which markets pay above the worldwide average, and by
-- how much?
-- ----------------------------------------------------------------------------
SELECT
    country,
    ROUND(AVG(salary), 0) AS avg_country_salary,
    ROUND(AVG(salary) - (SELECT AVG(salary) FROM job_market), 0) AS diff_from_global_avg
FROM job_market
GROUP BY country
HAVING AVG(salary) > (SELECT AVG(salary) FROM job_market)
ORDER BY avg_country_salary DESC;


-- ----------------------------------------------------------------------------
-- Q4. Year-over-year salary growth (WINDOW FUNCTION: LAG)
-- Business question: how has average pay trended 2022-2025, and what was the
-- year-over-year percentage change? (Cross-checks Phase 5 EDA Q10.)
-- ----------------------------------------------------------------------------
WITH yearly_avg AS (
    SELECT year, ROUND(AVG(salary), 0) AS avg_salary
    FROM job_market
    GROUP BY year
)
SELECT
    year,
    avg_salary,
    LAG(avg_salary) OVER (ORDER BY year) AS prev_year_salary,
    ROUND(
        100.0 * (avg_salary - LAG(avg_salary) OVER (ORDER BY year))
        / LAG(avg_salary) OVER (ORDER BY year), 2
    ) AS yoy_pct_change
FROM yearly_avg
ORDER BY year;


-- ----------------------------------------------------------------------------
-- Q5. Education level pay premium over High School baseline (CTE + subquery)
-- Business question: in dollar terms, how much does each education level add
-- over the baseline? (Cross-checks Phase 6 Tukey HSD results.)
-- ----------------------------------------------------------------------------
WITH edu_avg AS (
    SELECT education_level, ROUND(AVG(salary), 0) AS avg_salary
    FROM job_market
    GROUP BY education_level
)
SELECT
    education_level,
    avg_salary,
    avg_salary - (SELECT avg_salary FROM edu_avg WHERE education_level = 'High School') AS premium_over_highschool
FROM edu_avg
ORDER BY avg_salary;


-- ----------------------------------------------------------------------------
-- Q6. Company size x employment type matrix (AGGREGATION + CASE WHEN pivot-style)
-- Business question: does the company-size pay effect (Phase 5 Q8) hold
-- consistently across employment types, or does it vary?
-- ----------------------------------------------------------------------------
SELECT
    company_size,
    ROUND(AVG(CASE WHEN employment_type = 'full_time' THEN salary END), 0) AS full_time_avg,
    ROUND(AVG(CASE WHEN employment_type = 'part_time' THEN salary END), 0) AS part_time_avg,
    ROUND(AVG(CASE WHEN employment_type = 'freelance' THEN salary END), 0) AS freelance_avg,
    ROUND(AVG(CASE WHEN employment_type = 'internship' THEN salary END), 0) AS internship_avg,
    ROUND(AVG(CASE WHEN employment_type = 'work_from_home' THEN salary END), 0) AS wfh_avg
FROM job_market
GROUP BY company_size
ORDER BY FIELD(company_size, 'Small', 'Medium', 'Large', 'Enterprise');


-- ----------------------------------------------------------------------------
-- Q7. Percentile ranking of individual salaries within occupation (WINDOW FUNCTION)
-- Business question: for compensation review, where does each record sit
-- within its own occupation's pay distribution?
-- ----------------------------------------------------------------------------
SELECT
    occupation,
    country,
    salary,
    years_of_experience,
    ROUND(PERCENT_RANK() OVER (PARTITION BY occupation ORDER BY salary), 4) AS pct_rank_in_occupation,
    NTILE(4) OVER (PARTITION BY occupation ORDER BY salary) AS occupation_quartile
FROM job_market
WHERE occupation = 'Data Scientist'
ORDER BY salary DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- Q8. Gender pay gap check by country (AGGREGATION, cross-checks Phase 6 t-test)
-- Business question: does the near-zero gender gap found globally (Phase 6)
-- hold at the country level too, or does it vary by market?
-- ----------------------------------------------------------------------------
SELECT
    country,
    ROUND(AVG(CASE WHEN gender = 'Male' THEN salary END), 0) AS male_avg,
    ROUND(AVG(CASE WHEN gender = 'Female' THEN salary END), 0) AS female_avg,
    ROUND(
        AVG(CASE WHEN gender = 'Male' THEN salary END) -
        AVG(CASE WHEN gender = 'Female' THEN salary END), 0
    ) AS male_minus_female_gap
FROM job_market
GROUP BY country
ORDER BY ABS(male_minus_female_gap) DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- Q9. VIEW — reusable country/occupation salary summary for dashboard use
-- Business purpose: a single, always-current view Power BI (or any BI tool)
-- can query directly instead of re-deriving these aggregates repeatedly.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_country_occupation_summary AS
SELECT
    country,
    occupation,
    field,
    COUNT(*) AS n_records,
    ROUND(AVG(salary), 0) AS avg_salary,
    ROUND(AVG(years_of_experience), 1) AS avg_experience,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary
FROM job_market
GROUP BY country, occupation, field;

SELECT * FROM vw_country_occupation_summary
ORDER BY avg_salary DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- Q10. Top earner per occupation, per country (WINDOW FUNCTION: ROW_NUMBER)
-- Business question: who is the single highest earner in each country x
-- occupation combination — useful for outlier review / retention-risk flags.
-- ----------------------------------------------------------------------------
WITH ranked_earners AS (
    SELECT
        country,
        occupation,
        salary,
        years_of_experience,
        education_level,
        ROW_NUMBER() OVER (PARTITION BY country, occupation ORDER BY salary DESC) AS rn
    FROM job_market
)
SELECT country, occupation, salary, years_of_experience, education_level
FROM ranked_earners
WHERE rn = 1
ORDER BY salary DESC
LIMIT 15;


-- ----------------------------------------------------------------------------
-- Q11. VIEW — salary band summary (exact Phase 4 quartile cutoffs, reconciled above)
-- Business purpose: a queryable, always-current salary-band cut for BI tools,
-- guaranteed consistent with the Python-side salary_band feature.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_salary_band_summary AS
SELECT
    CASE
        WHEN salary <= 142798 THEN 'Low'
        WHEN salary <= 200229 THEN 'Mid'
        WHEN salary <= 267816 THEN 'High'
        ELSE 'Very High'
    END AS salary_band,
    country, occupation, education_level, company_size, salary, years_of_experience, year
FROM job_market;

SELECT salary_band, COUNT(*) AS n_records
FROM vw_salary_band_summary
GROUP BY salary_band
ORDER BY n_records DESC;


-- ----------------------------------------------------------------------------
-- Q12. VIEW — country x year trend (AGGREGATION, feeds the dashboard's trend page)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_country_yearly_trend AS
SELECT country, year, COUNT(*) AS n_records, ROUND(AVG(salary), 0) AS avg_salary
FROM job_market
GROUP BY country, year;

SELECT * FROM vw_country_yearly_trend
WHERE country = 'United States'
ORDER BY year;
