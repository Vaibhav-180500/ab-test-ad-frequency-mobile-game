-- Calculation of D1 retention and combining with user level metrics for a full user metrics view

CREATE OR REPLACE VIEW `table-name` AS

WITH user_sessions AS (
  SELECT 
    user_id,
    DATE(open_at) AS session_date,
    MIN(DATE(open_at)) OVER (PARTITION BY user_id) AS first_session_date
  FROM `table-name`
),

d1_check AS (
  SELECT 
    user_id,
    first_session_date,
    MAX(
      CASE 
        WHEN session_date = DATE_ADD(first_session_date, INTERVAL 1 DAY) 
        THEN 1 
        ELSE 0 
      END
    ) AS returned_d1
  FROM user_sessions
  GROUP BY user_id, first_session_date
),

d1_retention AS (
SELECT 
  user_id,
  first_session_date,
  returned_d1
FROM d1_check
)

SELECT 
  m.*,
  d.returned_d1
FROM `table-name` m
LEFT JOIN d1_retention d
  ON m.user_id = d.user_id;

