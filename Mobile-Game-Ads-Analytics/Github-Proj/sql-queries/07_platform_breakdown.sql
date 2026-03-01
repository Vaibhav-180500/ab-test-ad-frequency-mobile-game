-- Platform breakdown

SELECT 
  platform,
  ab_cohort_name,
  COUNT(DISTINCT user_id) AS total_users,
  
  -- Primary KPIs
  ROUND(AVG(total_revenue), 6) AS arpu,
  ROUND(AVG(returned_d1) * 100, 2) AS d1_retention_pct,
  
  -- Engagement
  ROUND(AVG(total_sessions), 2) AS avg_sessions_per_user,
  ROUND(AVG(avg_session_length), 2) AS avg_session_length_sec,
  ROUND(AVG(median_session_length), 2) AS avg_median_session_length_sec

FROM `table-name`
GROUP BY platform, ab_cohort_name
ORDER BY platform, arpu DESC;
