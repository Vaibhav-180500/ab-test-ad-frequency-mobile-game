-- User-level base metrics view

CREATE OR REPLACE VIEW `table-name` AS

SELECT 
  user_id,
  ANY_VALUE(platform) AS platform,
  ANY_VALUE(region) AS region,
  ANY_VALUE(ab_cohort_name) AS ab_cohort_name,
  ANY_VALUE(segment_name) AS segment_name,
  
  -- Acquisition timing
  MIN(open_at) AS first_session_at,
  MIN(acquired_at) AS acquired_at,
  
  -- Revenue metrics
  SUM(publisher_revenue) AS total_revenue,
  COUNT(*) AS total_sessions,
  ROUND(AVG(session_length), 2) AS avg_session_length,
  APPROX_QUANTILES(session_length, 100)[OFFSET(50)] AS median_session_length,
  
  -- Ad exposure
  SUM(fs_shown) AS total_fs_shown,
  SUM(rv_shown) AS total_rv_shown,
  SUM(activity_count) AS total_activity_count

FROM `table-name`
GROUP BY user_id;

