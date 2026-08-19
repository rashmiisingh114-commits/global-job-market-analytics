 # Power BI Dashboard — Build Specification

**Note on scope:** Power BI Desktop is a Windows GUI application and can't be executed in this project's analysis environment. This document is the complete design spec — layout, pages, filters, and DAX measures — for building the actual `.pbix` file yourself. Everything here is designed to plug directly into the SQL views already built in `sql/business_queries.sql`, so no additional data modeling is needed beyond connecting Power BI to those views (or to `data/processed/job_market_features.parquet` if you prefer a file-based source).

## Data Source

Connect Power BI to:
- **MySQL** (`Get Data → Database → MySQL Database`), pointing at `job_market_analytics`, using `vw_salary_band_summary`, `vw_country_yearly_trend`, and `vw_country_occupation_summary` as the primary sources — these are pre-aggregated, keeping the dashboard fast and the business logic centralized in the database rather than duplicated in DAX.
- Or, more simply: `job_market_features.parquet` directly (`Get Data → More → Parquet`), if you'd rather not stand up MySQL for this step.

## Page 1 — Executive Summary

**KPIs (top row, card visuals):**
- Overall Average Salary
- Total Records
- Highest-Paying Country (Switzerland)
- Highest-Paying Occupation (AI Engineer)

**Main visuals:**
- Bar chart: Average Salary by Country (Q1 finding)
- Bar chart: Average Salary by Occupation (Q3 finding)
- Line chart: Year-over-year Average Salary trend (Q10/SQL Q4 finding — note the decelerating growth rate in a tooltip)

**Filters (slicers, top of page, applied across all pages via sync):** Country, Year, Education Level, Company Size

## Page 2 — Salary Analysis

- Box plot (or Line/Clustered Column as a substitute, since Power BI's native box plot needs a custom visual): Salary distribution by Education Level — annotate with the $23K–28K per-level premium finding
- Clustered bar: Salary by Company Size — annotate with the 34% Small-to-Enterprise gap
- **Tooltip page:** hovering any education-level bar should show a tooltip page with the exact Tukey HSD pairwise differences (from `04_statistical_analysis.ipynb`)

## Page 3 — Country Analysis

- Map visual (Filled Map or ArcGIS Map): Average Salary by Country
- Table: Country × Occupation summary, sourced directly from `vw_country_occupation_summary`
- **Caveat callout (text box, always visible on this page):** "Salary assumed USD-normalized across countries — see Data Dictionary for details."

## Page 4 — Occupation & Industry Analysis

- Bar chart: Average Salary by Occupation, colored by Field
- **Drill-through page:** clicking a Field bar drills through to a detail page showing all occupations within that field (surfaces the Technology field's $28K internal spread, per Phase 5 Q4)

## Page 5 — Hiring & Trends

- Line chart: Record volume by year and month — **label explicitly as "Record Volume," never "Hiring Trend"** (per Phase 5's finding that this dataset has no real hiring-activity signal)
- Line chart: Average Salary trend by Year, with a slicer to select Country (powered by `vw_country_yearly_trend`)

## Page 6 — ML Insights

- Bar chart: SHAP global feature importance (import the values/image from `08_explainable_ai.ipynb` — Power BI can't compute SHAP natively, so this page presents the pre-computed results)
- Table: Model comparison (R², RMSE, MAE for all 5 regression models, and Accuracy/F1/ROC AUC for all 4 classification models) — static table from Phase 7's results
- Text callout: the negative-prediction limitation from Phase 8, so this caveat travels with the dashboard, not just the notebook

## Suggested DAX Measures

```dax
Average Salary = AVERAGE(job_market[salary])

YoY Salary Growth % =
VAR CurrentYearAvg = AVERAGE(job_market[salary])
VAR PriorYearAvg =
    CALCULATE(AVERAGE(job_market[salary]), PREVIOUSYEAR(job_market[year]))
RETURN DIVIDE(CurrentYearAvg - PriorYearAvg, PriorYearAvg)

Education Premium vs High School =
VAR HighSchoolAvg =
    CALCULATE(AVERAGE(job_market[salary]), job_market[education_level] = "High School")
RETURN AVERAGE(job_market[salary]) - HighSchoolAvg

Salary Band =
SWITCH(
    TRUE(),
    job_market[salary] <= 142798, "Low",
    job_market[salary] <= 200229, "Mid",
    job_market[salary] <= 267816, "High",
    "Very High"
)
```

## Navigation, Bookmarks, and Interactivity

- Use a consistent left-side navigation pane (buttons linking to each page) rather than relying on page tabs alone — standard for executive-facing dashboards.
- Bookmark two states on Page 1: "Global View" (no filters) and "Current Year Only" (Year slicer set to the latest year) — toggle button in the top-right corner.
- Enable cross-filtering between the Country map (Page 3) and the Occupation bar chart (Page 4) so clicking a country filters the occupation breakdown.

## Caveats to Surface in the Dashboard Itself (not just the README)

Add a small text box, visible on Page 1 and Page 3, stating: *"This dataset shows indicators of synthetic generation and assumes USD-normalized salary across countries. See the project's Data Dictionary for full detail."* A dashboard that hides its own data caveats behind a README nobody reads is a common real-world failure mode — don't repeat it here.
