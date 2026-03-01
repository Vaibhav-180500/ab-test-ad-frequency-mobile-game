-- Cleaned session view

CREATE OR REPLACE VIEW `table-name` AS
WITH deduped AS (
  -- Remove duplicate session_ids, keep record with max session_length
  SELECT 
    session_id,
    user_id,
    platform,
    country,
    open_at,
    acquired_at,
    ab_name,
    ab_cohort_name,
    segment_name,
    session_number_,
    MAX(session_length) AS session_length,
    MAX(publisher_revenue) AS publisher_revenue,
    MAX(fs_shown) AS fs_shown,
    MAX(rv_shown) AS rv_shown,
    MAX(game_count) AS activity_count,
    MAX(offline_game_count) AS offline_activity_count
  FROM `table-name`
  GROUP BY 
    session_id, user_id, platform, country, open_at, 
    acquired_at, ab_name, ab_cohort_name, segment_name, session_number_
),

cleaned AS (SELECT *
FROM deduped
WHERE 
  -- Keep only valid sessions
  user_id IS NOT NULL
  AND session_id IS NOT NULL
  AND session_length > 0
  AND ab_cohort_name IS NOT NULL
  AND ab_cohort_name != 'nan'
  -- Focus on new users (Android/iOS new_users segments)
  AND segment_name IN ('android_new_users', 'ios_new_users')
  )

-- Country/region grouping
SELECT *,
  CASE 
    WHEN country IN ('US', 'CA') THEN 'North America'
    WHEN country IN ('GB', 'FR', 'DE', 'IT', 'ES', 'NL', 'BE', 'SE', 'NO', 'DK', 'FI', 'IE', 'AT', 'CH', 'PT', 'PL', 'CZ', 'GR', 'RU', 'UA', 'BY') THEN 'Europe'
    WHEN country IN ('BR', 'MX', 'AR', 'CO', 'CL', 'PE', 'EC', 'BO', 'CR', 'GT', 'HN', 'NI', 'PA', 'PY', 'SV', 'UY', 'VE') THEN 'LATAM'
    WHEN country IN ('IN', 'ID', 'PH', 'TH', 'VN', 'MY', 'SG', 'PK', 'BD', 'MM', 'KH', 'LA', 'NP', 'LK', 'CN', 'JP', 'KR', 'TW', 'HK', 'MO', 'AU', 'NZ') THEN 'Asia-Pacific'
    WHEN country IN ('AE', 'SA', 'IL', 'TR', 'EG', 'IQ', 'JO', 'KW', 'LB', 'OM', 'QA', 'BH', 'IR', 'PS', 'SY', 'ZA', 'NG', 'KE', 'GH', 'ET', 'TZ', 'UG', 'ZW', 'ZM', 'MA', 'DZ', 'TN', 'CI', 'CM', 'SN', 'MZ', 'MU', 'GA', 'CG', 'CV', 'SO', 'DJ', 'GM', 'SZ', 'ML', 'MG', 'SC', 'GQ', 'GW', 'MR', 'LC') THEN 'MEA (Middle East & Africa)'
    ELSE 'Other'
  END AS region

FROM cleaned;

