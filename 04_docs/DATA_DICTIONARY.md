# Data Dictionary

## Raw / Cleaned Columns (present from `data/raw/job_market_raw.csv` onward)

| Column | Type | Description | Notes |
|---|---|---|---|
| `country` | string (21 categories) | Country of employment | Assumed independent of currency normalization — see Data Provenance below |
| `city` | string (22 categories) | City of employment | US uniquely has 2 cities (New York, San Francisco); every other country has 1 |
| `occupation` | string (12 categories) | Specific job title | Maps 1:1 to `field` |
| `field` | string (7 categories) | Broader industry/function grouping | Redundant with `occupation` for modeling — Technology field alone spans 5 distinct occupations |
| `years_of_experience` | integer (0–25) | Years of professional experience | Non-linear relationship with salary (diminishing returns after ~5 years) |
| `salary` | integer ($12,000–$370,000) | Annual compensation | **Assumed USD-normalized across countries — unverifiable, explicit assumption, not a fact.** Hard ceiling at $370,000 observed (synthetic-data artifact) |
| `employment_type` | string (5 categories) | full_time / part_time / freelance / internship / work_from_home | Surprisingly small pay gaps between categories — likely synthetic-data artifact, not a real-world signal |
| `education_level` | string (4 categories, ordinal) | High School / Bachelor / Master / PhD | Strong, monotonic, statistically confirmed salary driver (Phase 6 ANOVA eta²=0.113) |
| `gender` | string (3 categories) | Male / Female / Other | **No statistically significant salary effect found** (Phase 6: p=0.204, Cohen's d=0.0044). Given the synthetic dataset, do not treat as evidence about real-world pay equity |
| `company_size` | string (4 categories, ordinal) | Small / Medium / Large / Enterprise | Strong, monotonic salary driver; interacts meaningfully with education (Phase 7 clustering) |
| `year` | integer (2022–2025) | Record year | Weak but real upward salary trend (~2.5–3.2% YoY, decelerating) |
| `month` | integer (1–12) | Record month | No meaningful salary signal — safe to exclude from modeling |
| `salary_outlier_flag` | boolean | Flags salary as a statistical outlier within its country × occupation × employment_type group | Informational only — root cause traced to rare-but-real attribute combinations (e.g., a PhD recorded as an intern), not data errors. See `01_data_cleaning.ipynb` |

## Engineered Features (added in `02_feature_engineering.ipynb`, present in `job_market_features.parquet`)

| Column | Derived From | Safe as Model Predictor? | Description |
|---|---|---|---|
| `experience_level` | `years_of_experience` | ✅ Yes | Junior / Mid / Senior / Executive bucket |
| `quarter` | `month` | ✅ Yes | Q1–Q4 grouping |
| `region` | `country` | ✅ Yes | Continent-level grouping (North America, Europe, Asia, etc.) |
| `salary_band` | `salary` | ❌ **No — target leakage** | Quartile bucket (Low/Mid/High/Very High). Use only for EDA or as the Phase 7 classification **target** |
| `high_salary_indicator` | `salary` | ❌ **No — target leakage** | Binary: above/below own-country median salary |
| `salary_per_experience_year` | `salary`, `years_of_experience` | ❌ **No — target leakage** | Descriptive "pay efficiency" ratio, EDA only |
| `top_occupation_indicator` | `occupation` (aggregated) | ⚠️ Caution | Flags top-quartile-paying occupations. Safe as a feature only if recomputed from the training fold alone in any train/test split |
| `cluster` | K-Means output | N/A (unsupervised) | Job-market segment label (0–3), added in `07_ml_clustering.ipynb`. See segment names in `docs/business_insights.md` |

## Explicitly Rejected / Not Engineered

| Candidate Feature (from original brief) | Why It Was Skipped |
|---|---|
| `Demand Score` | No real labor-demand signal exists in the data (no postings/applicants/time-to-fill). Fabricating one from row counts would misrepresent sample size as a business metric. |
| `Salary Growth Category` | This dataset is cross-sectional (one row per person-instance), not a panel tracking the same individual over time — individual salary growth cannot be computed. Aggregate year-over-year trend is covered in EDA instead. |

## Data Provenance & Limitations (carried throughout the project)

- This dataset shows strong indicators of **synthetic generation**: zero missing values across all 500,000 raw rows, near-perfectly balanced categorical distributions, and a hard salary ceiling at $370,000 reached by many unrelated records.
- **Currency normalization is assumed, not verified** — no currency/FX field exists in the source data.
- Findings should be read as **patterns within this dataset**, useful for demonstrating methodology, not as verified real-world labor-market facts — this applies with special force to the gender pay-gap finding.
