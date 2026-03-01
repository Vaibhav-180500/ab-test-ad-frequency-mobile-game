-- Check for data quality issues

-- Missing user_ids
SELECT COUNT(*) AS missing_user_id
FROM `table-name`
WHERE user_id IS NULL;

-- Missing or invalid session_length (≤0 or NULL)
SELECT 
  COUNT(*) AS invalid_session_length,
  COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `table-name`) AS pct
FROM `table-name`
WHERE session_length IS NULL OR session_length <= 0;

-- Missing cohort assignment
SELECT 
  COUNT(*) AS missing_cohort,
  COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `table-name`) AS pct
FROM `table-name`
WHERE ab_cohort_name IS NULL;

-- Check for duplicate session_ids
WITH session_length_not_zero AS (
  SELECT *
  FROM `table-name`
  WHERE session_length > 0 AND session_length IS NOT NULL
)
SELECT 
  session_id, 
  COUNT(*) AS dup_count
FROM session_length_not_zero
GROUP BY session_id
HAVING COUNT(*) > 1;


