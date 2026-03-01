-- Initial data profiling queries

-- Total sessions
SELECT COUNT(*) AS total_rows
FROM `table-name`;

-- Date range of experiment
SELECT 
  MIN(DATE(open_at)) AS experiment_start,
  MAX(DATE(open_at)) AS experiment_end,
  DATE_DIFF(MAX(DATE(open_at)), MIN(DATE(open_at)), DAY) AS duration_days
FROM `table-name`;

-- Platforms
SELECT 
  platform,
  COUNT(*) AS sessions,
  COUNT(DISTINCT user_id) AS users
FROM `table-name`
GROUP BY platform
ORDER BY sessions DESC;

-- Cohorts
SELECT 
  ab_cohort_name,
  COUNT(*) AS sessions,
  COUNT(DISTINCT user_id) AS users
FROM `table-name`
GROUP BY ab_cohort_name
ORDER BY sessions DESC;

-- Segments
SELECT 
  segment_name,
  COUNT(*) AS sessions,
  COUNT(DISTINCT user_id) AS users
FROM `table-name`
GROUP BY segment_name
ORDER BY sessions DESC;
