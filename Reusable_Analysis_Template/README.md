# A/B Test Analysis Template
> A complete, reusable framework for end-to-end A/B test analysis — from raw data to business recommendation.

---

## Table of Contents
1. [Stage 1: Data Understanding & Profiling](#stage-1-data-understanding--profiling)
2. [Stage 2: Metric Construction (SQL)](#stage-2-metric-construction-sql)
3. [Stage 3: Statistical Testing (Python)](#stage-3-statistical-testing-python)
4. [Stage 4: Decision Framework](#stage-4-decision-framework)
5. [Stage 5: Reporting Checklist](#stage-5-reporting-checklist)

---

## Stage 1: Data Understanding & Profiling

### 1A. Understand the Business Context

Before touching any data, answer these questions:

```
- What is the product/feature being tested?
- What is the hypothesis? (If we do X, then Y will improve)
- What is the primary success metric?
- What are the guardrail metrics? (things we must NOT harm)
- What is the test duration and sample size?
- What are the cohorts and what do they represent?
```

### 1B. SQL — Data Profiling

```sql
-- 1. Understand the date range
SELECT
    DATE(MIN(created_at)) AS start_date,
    DATE(MAX(created_at)) AS end_date
FROM your_table;

-- 2. Understand cohort names and sizes
SELECT
    cohort_name,
    COUNT(DISTINCT user_id) AS user_count
FROM your_table
GROUP BY cohort_name
ORDER BY user_count DESC;

-- 3. Check platform / region / segment distribution
SELECT
    platform,
    region,
    cohort_name,
    COUNT(DISTINCT user_id) AS users
FROM your_table
GROUP BY 1, 2, 3;
```

### 1C. SQL — Data Quality Checks

```sql
-- 1. Check for NULL user_ids
SELECT COUNT(*) AS missing_users
FROM your_table
WHERE user_id IS NULL;

-- 2. Check for invalid values (negative durations, zero values, etc.)
SELECT *
FROM your_table
WHERE session_length <= 0
   OR revenue < 0;

-- 3. Check for duplicates
SELECT
    user_id,
    session_id,
    COUNT(*) AS dup_count
FROM your_table
GROUP BY user_id, session_id
HAVING COUNT(*) > 1;

-- 4. Check cohort balance (are groups roughly equal?)
SELECT
    cohort_name,
    COUNT(DISTINCT user_id) AS users,
    ROUND(
        COUNT(DISTINCT user_id) * 100.0 / SUM(COUNT(DISTINCT user_id)) OVER(), 2
    ) AS pct
FROM your_table
GROUP BY cohort_name;
```

---

## Stage 2: Metric Construction (SQL)

### 2A. Build a Cleaned Base View

```sql
CREATE OR REPLACE VIEW cleaned_sessions AS
SELECT
    user_id,
    session_id,
    ANY_VALUE(cohort_name)  AS cohort_name,
    ANY_VALUE(platform)     AS platform,
    ANY_VALUE(region)       AS region,
    MAX(session_length)     AS session_length,
    MAX(revenue)            AS revenue,
    MAX(session_number)     AS session_number,
    MAX(created_at)         AS created_at
FROM your_table
WHERE session_length > 0         -- Remove invalid sessions
GROUP BY user_id, session_id;    -- Deduplicate
```

### 2B. Build User-Level Metrics Table

> ⚠️ **Always aggregate to USER level** for A/B tests — not session level — to avoid pseudo-replication.

```sql
CREATE OR REPLACE TABLE user_metrics AS
WITH first_session AS (
    SELECT
        user_id,
        MIN(created_at) AS first_seen_at
    FROM cleaned_sessions
    GROUP BY user_id
),
user_activity AS (
    SELECT
        s.user_id,
        ANY_VALUE(s.cohort_name)    AS cohort_name,
        ANY_VALUE(s.platform)       AS platform,
        ANY_VALUE(s.region)         AS region,

        -- PRIMARY METRIC
        SUM(s.revenue)              AS total_revenue,

        -- GUARDRAIL 1: Retention
        MAX(CASE
            WHEN DATE(s.created_at) = DATE(f.first_seen_at) + 1
            THEN 1 ELSE 0
        END)                        AS returned_d1,

        -- GUARDRAIL 2: Engagement
        COUNT(DISTINCT s.session_id)            AS total_sessions,
        AVG(s.session_length)                   AS avg_session_length,
        PERCENTILE_CONT(s.session_length, 0.5)
            OVER (PARTITION BY s.user_id)       AS median_session_length

        -- Add any other metrics relevant to your case
    FROM cleaned_sessions s
    JOIN first_session f ON s.user_id = f.user_id
    GROUP BY s.user_id
)
SELECT * FROM user_activity;
```

### 2C. EDA Aggregations

```sql
-- Global summary by cohort
SELECT
    cohort_name,
    COUNT(DISTINCT user_id)     AS total_users,
    AVG(total_revenue)          AS arpu,
    AVG(returned_d1) * 100      AS d1_retention_pct,
    AVG(total_sessions)         AS avg_sessions_per_user,
    AVG(avg_session_length)     AS avg_session_length_sec
FROM user_metrics
GROUP BY cohort_name
ORDER BY arpu DESC;

-- Platform breakdown
SELECT
    platform,
    cohort_name,
    COUNT(DISTINCT user_id)     AS total_users,
    AVG(total_revenue)          AS arpu,
    AVG(returned_d1) * 100      AS d1_retention_pct,
    AVG(avg_session_length)     AS avg_session_length_sec
FROM user_metrics
GROUP BY platform, cohort_name
ORDER BY platform, arpu DESC;

-- Region breakdown
SELECT
    region,
    cohort_name,
    COUNT(DISTINCT user_id)     AS total_users,
    AVG(total_revenue)          AS arpu,
    AVG(returned_d1) * 100      AS d1_retention_pct,
    AVG(avg_session_length)     AS avg_session_length_sec
FROM user_metrics
WHERE region != 'Other'
GROUP BY region, cohort_name
ORDER BY region, arpu DESC;
```

---

## Stage 3: Statistical Testing (Python)

### 3A. Setup

```python
import pandas as pd
import numpy as np
from scipy import stats
from statsmodels.stats.proportion import proportions_ztest
import warnings
warnings.filterwarnings('ignore')

# Load user-level data
df = pd.read_csv('user_metrics.csv')

# Quick sanity checks
print(f"Total users: {len(df):,}")
print(f"Cohorts:     {df['cohort_name'].unique()}")
print(f"Platforms:   {df['platform'].unique()}")
print(f"Regions:     {df['region'].unique()}")
print(df.groupby('cohort_name').size())
```

### 3B. Helper Functions

#### T-Test — continuous metrics (ARPU, session length)

```python
def ttest_vs_control(df, metric, cohort, control='control',
                     platform=None, region=None):
    df_f = df.copy()
    if platform: df_f = df_f[df_f['platform'] == platform]
    if region:   df_f = df_f[df_f['region'] == region]

    ctrl = df_f[df_f['cohort_name'] == control][metric].dropna()
    trt  = df_f[df_f['cohort_name'] == cohort][metric].dropna()

    if len(ctrl) < 30 or len(trt) < 30:
        return None

    t_stat, p_value = stats.ttest_ind(trt, ctrl, equal_var=False)
    delta     = trt.mean() - ctrl.mean()
    delta_pct = delta / ctrl.mean() * 100 if ctrl.mean() != 0 else 0
    se        = np.sqrt(ctrl.var()/len(ctrl) + trt.var()/len(trt))

    return {
        'control_mean': ctrl.mean(),
        'cohort_mean':  trt.mean(),
        'delta':        delta,
        'delta_pct':    delta_pct,
        'p_value':      p_value,
        'significant':  p_value < 0.05,
        'ci_lower':     delta - 1.96 * se,
        'ci_upper':     delta + 1.96 * se,
        'control_n':    len(ctrl),
        'cohort_n':     len(trt)
    }
```

#### Z-Test — proportions (D1 retention, conversion rates)

```python
def proptest_vs_control(df, binary_metric, cohort, control='control',
                        platform=None, region=None):
    df_f = df.copy()
    if platform: df_f = df_f[df_f['platform'] == platform]
    if region:   df_f = df_f[df_f['region'] == region]

    ctrl = df_f[df_f['cohort_name'] == control][binary_metric].dropna()
    trt  = df_f[df_f['cohort_name'] == cohort][binary_metric].dropna()

    if len(ctrl) < 30 or len(trt) < 30:
        return None

    counts = np.array([trt.sum(), ctrl.sum()])
    nobs   = np.array([len(trt), len(ctrl)])
    z_stat, p_value = proportions_ztest(counts, nobs)

    p_ctrl   = ctrl.mean()
    p_trt    = trt.mean()
    delta_pp = (p_trt - p_ctrl) * 100
    se = np.sqrt(p_ctrl*(1-p_ctrl)/len(ctrl) + p_trt*(1-p_trt)/len(trt))

    return {
        'control_prop': p_ctrl * 100,
        'cohort_prop':  p_trt  * 100,
        'delta_pp':     delta_pp,
        'p_value':      p_value,
        'significant':  p_value < 0.05,
        'ci_lower':     (p_trt - p_ctrl - 1.96*se) * 100,
        'ci_upper':     (p_trt - p_ctrl + 1.96*se) * 100,
        'control_n':    len(ctrl),
        'cohort_n':     len(trt)
    }
```

#### Mann-Whitney U Test — medians (non-parametric)

```python
def mannwhitney_vs_control(df, metric, cohort, control='control',
                           platform=None, region=None):
    df_f = df.copy()
    if platform: df_f = df_f[df_f['platform'] == platform]
    if region:   df_f = df_f[df_f['region'] == region]

    ctrl = df_f[df_f['cohort_name'] == control][metric].dropna()
    trt  = df_f[df_f['cohort_name'] == cohort][metric].dropna()

    if len(ctrl) < 30 or len(trt) < 30:
        return None

    u_stat, p_value = stats.mannwhitneyu(trt, ctrl, alternative='two-sided')
    delta     = trt.median() - ctrl.median()
    delta_pct = delta / ctrl.median() * 100 if ctrl.median() != 0 else 0

    return {
        'control_median': ctrl.median(),
        'cohort_median':  trt.median(),
        'delta':          delta,
        'delta_pct':      delta_pct,
        'p_value':        p_value,
        'significant':    p_value < 0.05,
        'control_n':      len(ctrl),
        'cohort_n':       len(trt)
    }
```

### 3C. Run Analysis: Global, Platform, Region

```python
# ── Define your analysis dimensions ──────────────────────────────────────
CONTROL     = 'control'
CANDIDATES  = ['variantA', 'variantB']   # Replace with your cohorts
PLATFORMS   = df['platform'].unique().tolist()
REGIONS     = [r for r in df['region'].unique() if pd.notnull(r) and r != 'Other']

PRIMARY_METRIC       = 'total_revenue'
GUARDRAIL_BINARY     = 'returned_d1'
GUARDRAIL_CONTINUOUS = 'avg_session_length'
GUARDRAIL_MEDIAN     = 'median_session_length'

# ── Generic runner ────────────────────────────────────────────────────────
def run_full_analysis(df, cohorts, primary, guardrail_binary,
                      guardrail_cont, guardrail_median,
                      platform=None, region=None):
    results = []
    for cohort in cohorts:
        arpu  = ttest_vs_control(df, primary, cohort, platform=platform, region=region)
        d1    = proptest_vs_control(df, guardrail_binary, cohort, platform=platform, region=region)
        avg_s = ttest_vs_control(df, guardrail_cont, cohort, platform=platform, region=region)
        med_s = mannwhitney_vs_control(df, guardrail_median, cohort, platform=platform, region=region)

        if arpu and d1 and avg_s and med_s:
            results.append({
                'cohort':                cohort,
                'arpu_delta_pct':        arpu['delta_pct'],
                'arpu_pvalue':           arpu['p_value'],
                'd1_delta_pp':           d1['delta_pp'],
                'd1_pvalue':             d1['p_value'],
                'avg_session_delta_pct': avg_s['delta_pct'],
                'avg_session_pvalue':    avg_s['p_value'],
                'med_session_delta_pct': med_s['delta_pct'],
                'med_session_pvalue':    med_s['p_value'],
            })
    return pd.DataFrame(results)

# Run globally
df_global = run_full_analysis(df, CANDIDATES, PRIMARY_METRIC,
                               GUARDRAIL_BINARY, GUARDRAIL_CONTINUOUS, GUARDRAIL_MEDIAN)

# Run per platform
df_platform = pd.concat([
    run_full_analysis(df, CANDIDATES, PRIMARY_METRIC,
                      GUARDRAIL_BINARY, GUARDRAIL_CONTINUOUS,
                      GUARDRAIL_MEDIAN, platform=p).assign(platform=p)
    for p in PLATFORMS
])

# Run per region
df_region = pd.concat([
    run_full_analysis(df, CANDIDATES, PRIMARY_METRIC,
                      GUARDRAIL_BINARY, GUARDRAIL_CONTINUOUS,
                      GUARDRAIL_MEDIAN, region=r).assign(region=r)
    for r in REGIONS
])
```

---

## Stage 4: Decision Framework

### 4A. Define Thresholds

```python
# Customize per project based on business context
THRESHOLDS = {
    # Primary metric
    'arpu_min_uplift_pct':      3.0,    # Minimum % uplift required
    'arpu_pvalue':              0.10,   # Significance level for primary metric

    # Guardrail: D1 Retention
    'd1_max_drop_pp':           1.0,    # Max allowed drop in percentage points

    # Guardrail: Avg Session Length
    'avg_session_max_drop_pct': 3.0,    # Max allowed % drop

    # Guardrail: Median Session Length
    'med_session_max_drop_pct': 4.0,    # Max allowed % drop
}
```

### 4B. Tiered Verdict Logic

| Metric | If NOT Significant (p ≥ 0.05) | If Significant (p < 0.05) |
|--------|-------------------------------|---------------------------|
| Primary (ARPU) | FAIL — no proven uplift | Must meet min uplift threshold |
| D1 Retention | Auto **PASS** | Drop must be ≤ max allowed |
| Avg Session Length | Auto **PASS** | Drop must be ≤ max allowed |
| Median Session Length | Auto **PASS** | Drop must be ≤ max allowed |

> **Why tiered?** A non-significant change = no proven effect → auto pass on guardrails.
> A significant change = proven effect → must stay within strict limits.
> This correctly penalizes variants with *proven* engagement damage.

```python
def verdict(row, t=THRESHOLDS):
    # Primary metric check
    if row['arpu_pvalue'] >= t['arpu_pvalue']:
        return 'FAIL'  # No proven uplift
    if row['arpu_delta_pct'] < t['arpu_min_uplift_pct']:
        return 'FAIL'  # Uplift too small

    # Guardrail checks (only penalise if significant)
    if row['d1_pvalue'] < 0.05 and row['d1_delta_pp'] < -t['d1_max_drop_pp']:
        return 'FAIL'
    if row['avg_session_pvalue'] < 0.05 and row['avg_session_delta_pct'] < -t['avg_session_max_drop_pct']:
        return 'FAIL'
    if row['med_session_pvalue'] < 0.05 and row['med_session_delta_pct'] < -t['med_session_max_drop_pct']:
        return 'FAIL'

    return 'PASS'

df_global['verdict'] = df_global.apply(verdict, axis=1)
```

---

## Stage 5: Reporting Checklist

Use this checklist before presenting results to stakeholders:

```
[ ] Sample sizes reported for all cohorts
[ ] Test duration stated
[ ] Primary metric result clearly highlighted
[ ] All guardrail metrics reported (even if passing)
[ ] Platform-level breakdown included
[ ] Region-level breakdown included
[ ] Statistical significance stated (p-values + confidence intervals)
[ ] Business recommendation is clear and actionable
[ ] Caveats / limitations acknowledged
[ ] Next steps defined (e.g. further testing, rollout plan)
```

### Results Summary Table Template

| Cohort | ARPU Uplift | p-value | D1 Change | Avg Session | Verdict |
|--------|-------------|---------|-----------|-------------|---------|
| variantA | +X.XX% | 0.0XX | -X.XX pp | +X.XX% | ✅ PASS / ❌ FAIL |
| variantB | +X.XX% | 0.0XX | -X.XX pp | +X.XX% | ✅ PASS / ❌ FAIL |

### Final Recommendation Template

```
Deploy [WINNING VARIANT] on [PLATFORM/REGION].
Keep control on [PLATFORM/REGION] until further testing.

Key reason: [X]% ARPU uplift with no statistically significant
harm to retention or engagement.
```

---

## Quick Reference: Which Test to Use?

| Metric Type | Test | Function |
|-------------|------|----------|
| Continuous mean (revenue, session length) | Welch's T-Test | `ttest_vs_control()` |
| Binary proportion (retention, conversion) | Z-Test for proportions | `proptest_vs_control()` |
| Median / skewed distributions | Mann-Whitney U | `mannwhitney_vs_control()` |

---

*Template by Vaibhav Kumar — Data Analyst | Paris, France*  
*[LinkedIn](https://www.linkedin.com/in/vaibhav-kumar1805/) | [Tableau Public](https://public.tableau.com/app/profile/vaibhav.kumar1063)*
