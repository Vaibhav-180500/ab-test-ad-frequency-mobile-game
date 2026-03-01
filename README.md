# A/B Test: Ad Frequency Optimization for a Cross-Platform Mobile Game

---

## 📊 Interactive Dashboard

> **Business users: Start here →**
> 
> ### 🔗 [View the Tableau Dashboard](https://public.tableau.com/views/ABtestingforaCrossPlatformMobileApp/ProblemContext)
> 
> *Explore the full interactive analysis — Executive Summary, ARPU trends, retention guardrails, platform & regional breakdowns.*

---

## Overview
End-to-end A/B test analysis designed to identify the optimal ad frequency 
for a mobile game, maximizing revenue (ARPU) without harming user retention 
or engagement. The project covers the full analytics workflow: from raw 
session-level data in BigQuery to statistical testing in Python and 
interactive dashboards in Tableau.

---

## Business Problem
Find the optimal ad frequency that:
- **Maximizes** ARPU (Average Revenue Per User)
- **Does not harm** D1 retention (day-1 return rate)
- **Does not significantly reduce** session length (engagement guardrail)

---

## Dataset
- **Source:** Session-level event data (mobile game)
- **Size:** ~100,000 users across 6 A/B cohorts
- **Platforms:** Android, iOS
- **Regions:** North America, Europe, Asia-Pacific, LATAM, MEA
- **Test period:** Feb 2020

### Cohorts Tested
| Cohort | Description |
|--------|-------------|
| `control` | Baseline ad frequency |
| `xxHigh` | Very high ad frequency |
| `xHigh` | High ad frequency |
| `gameTune` | Dynamic/adaptive ad frequency |
| `xLow` | Low ad frequency |
| `xxLow` | Very low ad frequency |

---

## Project Structure

```
├── README.md
├── sql/
│   ├── 01_data_profiling.sql
│   ├── 02_data_cleaning.sql
│   ├── 03_cleaned_session_view.sql
│   ├── 04_eda.sql
│   ├── 05_user_level_base_metrics.sql
│   ├── 06_user_metrics_full.sql
│   ├── 07_platform_breakdown.sql
│   └── 08_region_breakdown.sql
├── notebooks/
│   └── ab_test_statistical_analysis.ipynb
```

---

## Methodology

### Stage 1 & 2: SQL Data Pipeline (BigQuery)

The analysis follows an 8-step SQL pipeline:

| File | Description |
|------|-------------|
| `01_data_profiling.sql` | Initial exploration: date range, cohort names, sample sizes |
| `02_data_cleaning.sql` | Null checks, zero/negative session length removal, duplicate detection |
| `03_cleaned_session_view.sql` | Creates a cleaned session-level view as base for all downstream queries |
| `04_eda.sql` | Exploratory analysis: revenue distribution, session patterns, cohort balance |
| `05_user_level_base_metrics.sql` | Aggregates session data to user level (revenue, sessions, D1 flag) |
| `06_user_metrics_full.sql` | Full user-level metrics table: ARPU, D1, avg/median session length, lifecycle bucket |
| `07_platform_breakdown.sql` | Platform-level (Android/iOS) aggregations by cohort |
| `08_region_breakdown.sql` | Region-level aggregations by cohort |

### Stage 3: Statistical Testing (Python)

Applied a **tiered threshold framework**:

| Metric | If NOT Significant (p ≥ 0.05) | If Significant (p < 0.05) |
|--------|-------------------------------|---------------------------|
| ARPU uplift | — | ≥ +3.0% AND p < 0.10 |
| D1 retention | Auto PASS | Drop ≤ 1.0 pp |
| Avg session length | Auto PASS | Drop ≤ 3.0% |
| Median session length | Auto PASS | Drop ≤ 4.0% |

**Tests used:**
- **T-test (Welch):** ARPU and average session length (continuous metrics)
- **Z-test for proportions:** D1 retention
- **Mann-Whitney U test:** Median session length (non-parametric)

**Why tiered thresholds?**  
A non-significant change = no proven effect → automatic pass.  
A significant change = proven effect → must stay within strict limits.  
This correctly penalizes variants with *proven* engagement damage while 
rewarding variants with no statistically proven harm.

### Stage 4: Tableau Dashboards

Interactive story built across 6 dashboards:
1. Executive Summary
2. Problem & Context
3. Global Analysis – ARPU
4. Global Analysis – Guardrails
5. Platform Deep Dive
6. Regional Analysis

---

## Key Results

### Global
| Cohort | ARPU Uplift | D1 Change | Avg Session | Verdict |
|--------|-------------|-----------|-------------|---------|
| xxHigh | +4.11% ✅ | -0.18 pp ✅ | -3.23% ❌ | FAIL |
| **xHigh** | **+3.15% ✅** | **-0.44 pp ✅** | **+0.63% ✅** | **PASS** |
| gameTune | -0.01% ❌ | -0.44 pp ✅ | -2.18% ✅ | FAIL |

**Global winner: xHigh**  
+3.15% ARPU with no statistically significant engagement or retention impact.

### Platform
| Platform | Winner | ARPU Uplift |
|----------|--------|-------------|
| iOS | xHigh | +6.69% |
| Android | control | No variant passes |

### Region
| Region | Winner | ARPU Uplift |
|--------|--------|-------------|
| Europe | xHigh | +7.38% |
| North America | control | No significant uplift |
| Asia-Pacific | control | No significant uplift |
| LATAM | control | No significant uplift |
| MEA | control | No significant uplift |

---

## Final Recommendation

**Deploy xHigh on iOS globally and in Europe.**  
Keep control configuration on Android and in all other regions until 
further testing or variant tuning.

**gameTune verdict:** Not recommended. Provides no monetization advantage 
over fixed frequency rules and adds unnecessary operational complexity.

---

## Tools & Stack
| Layer | Tool |
|-------|------|
| Data warehouse | Google BigQuery |
| Data processing | SQL (window functions, CTEs) |
| Statistical analysis | Python (pandas, scipy, statsmodels) |
| Visualization | Tableau Public |
| Notebook | Google Colab |

---

## Author

**Vaibhav Kumar**  
Data Analyst | Paris, France  
[LinkedIn](https://www.linkedin.com/in/vaibhav-kumar1805/) | [Tableau Public](https://public.tableau.com/app/profile/vaibhav.kumar1063)
