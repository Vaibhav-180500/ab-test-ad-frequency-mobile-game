-- Summary exploration queries
-----------------------------------------------------------------------------------------------------------
-- Session length distribution by cohort

WITH cohort_percentiles AS (
  -- Step 1: Calculate the 5th and 95th percentiles per cohort
  SELECT 
    ab_cohort_name,
    APPROX_QUANTILES(session_length, 100)[OFFSET(5)] AS p05_limit,
    APPROX_QUANTILES(session_length, 100)[OFFSET(95)] AS p95_limit
  FROM `table-name`
  GROUP BY ab_cohort_name
)

-- Step 2: Join the percentiles back to the main table and aggregate
SELECT 
  s.ab_cohort_name,
  COUNT(s.session_length) AS total_sessions,
  
  -- Central tendency
  ROUND(AVG(s.session_length), 2) AS avg_session_length_sec,
  ROUND(STDDEV(s.session_length), 2) AS stddev_session_length,
  APPROX_QUANTILES(s.session_length, 100)[OFFSET(50)] AS median_session_length,
  
  -- Percentiles
  APPROX_QUANTILES(s.session_length, 100)[OFFSET(10)] AS p10_session_length,
  APPROX_QUANTILES(s.session_length, 100)[OFFSET(90)] AS p90_session_length,
  
  -- Trimmed mean (using the limits calculated in the CTE)
  ROUND(AVG(
    CASE 
      WHEN s.session_length >= p.p05_limit 
       AND s.session_length <= p.p95_limit
      THEN s.session_length 
    END
  ), 2) AS trimmed_mean_5pct

FROM `table-name` s
JOIN cohort_percentiles p 
  ON s.ab_cohort_name = p.ab_cohort_name
GROUP BY s.ab_cohort_name
ORDER BY avg_session_length_sec DESC;

-----------------------------------------------------------------------------------------------------------
-- Revenue distribution by cohort
WITH cte AS (
SELECT 
  ab_cohort_name,
  COUNT(DISTINCT user_id) AS users,
  ROUND(SUM(publisher_revenue), 4) AS total_revenue,
  ROUND(AVG(publisher_revenue), 6) AS avg_revenue_per_session,
  ROUND(APPROX_QUANTILES(publisher_revenue, 100)[OFFSET(50)], 6) AS median_revenue_per_session,
  ROUND(STDDEV(publisher_revenue), 2) AS stddev_revenue_per_session,
  ROUND(SUM(publisher_revenue) / COUNT(DISTINCT user_id), 6) AS revenue_per_user
FROM `table-name`
GROUP BY ab_cohort_name
)

SELECT *,
  ROUND(cte.total_revenue - (SELECT cte.total_revenue FROM cte WHERE ab_cohort_name = 'control'), 6) AS increase_in_total_revenue
FROM cte
ORDER BY cte.total_revenue DESC;

-----------------------------------------------------------------------------------------------------------
-- Ads shown per cohort

SELECT 
  ab_cohort_name,
  SUM(fs_shown) AS total_fs,
  ROUND(AVG(fs_shown), 2) AS avg_fs_per_session,
  SUM(rv_shown) AS total_rv,
  ROUND(AVG(rv_shown), 4) AS avg_rv_per_session,
  (SUM(rv_shown)+ SUM(fs_shown)) AS total_ads,
  ROUND(AVG(fs_shown + rv_shown), 2) AS avg_total_ads_per_session
FROM `table-name`
GROUP BY ab_cohort_name
ORDER BY avg_total_ads_per_session DESC;
