-- queries.sql
USE scdr;

-- Sanity: fact table coverage
SELECT COUNT(*) AS total_events, MIN(event_date) AS min_date, MAX(event_date) AS max_date FROM event;

-- View: events with human label and dims
DROP VIEW IF EXISTS v_events_with_flag;
CREATE VIEW v_events_with_flag AS
SELECT
  e.event_id,
  e.event_date,
  ct.crime_activity,
  CASE WHEN e.storm_flag = 1 THEN 'Storm' ELSE 'No Storm' END AS storm_flag,
  z.city,
  z.zone
FROM event e
JOIN crime_type ct ON ct.crime_type_id = e.crime_type_id
LEFT JOIN zone z ON z.zone_id = e.zone_id;

-- Crime type counts overall/by storm
DROP VIEW IF EXISTS v_crime_type_counts_by_storm;
CREATE VIEW v_crime_type_counts_by_storm AS
SELECT
  ct.crime_activity,
  CASE WHEN e.storm_flag = 1 THEN 'Storm' ELSE 'No Storm' END AS storm_flag,
  COUNT(*) AS event_count
FROM event e
JOIN crime_type ct ON ct.crime_type_id = e.crime_type_id
GROUP BY ct.crime_activity, storm_flag;

-- Monthly counts + cumulative (replaces combined_monthly_event_counts.csv)
DROP VIEW IF EXISTS v_monthly_event_counts;
CREATE VIEW v_monthly_event_counts AS
SELECT
  STR_TO_DATE(DATE_FORMAT(e.event_date, '%Y-%m-01'), '%Y-%m-%d') AS period_date,
  CASE WHEN e.storm_flag = 1 THEN 'Storm' ELSE 'No Storm' END AS storm_flag,
  COUNT(*) AS event_count
FROM event e
GROUP BY period_date, storm_flag;

DROP VIEW IF EXISTS v_combined_monthly_event_counts;
CREATE VIEW v_combined_monthly_event_counts AS
SELECT
  period_date,
  storm_flag,
  event_count,
  SUM(event_count) OVER (
    PARTITION BY storm_flag
    ORDER BY period_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cum_event_count
FROM v_monthly_event_counts
ORDER BY period_date, storm_flag;

-- Daily counts + cumulative (fallback when only a single month exists)
DROP VIEW IF EXISTS v_daily_event_counts;
CREATE VIEW v_daily_event_counts AS
SELECT
  DATE(e.event_date) AS period_date,
  CASE WHEN e.storm_flag = 1 THEN 'Storm' ELSE 'No Storm' END AS storm_flag,
  COUNT(*) AS event_count
FROM event e
GROUP BY period_date, storm_flag;

DROP VIEW IF EXISTS v_cumulative_event_counts_daily;
CREATE VIEW v_cumulative_event_counts_daily AS
SELECT
  period_date,
  storm_flag,
  event_count,
  SUM(event_count) OVER (
    PARTITION BY storm_flag
    ORDER BY period_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cum_event_count
FROM v_daily_event_counts
ORDER BY period_date, storm_flag;

-- Top N crime types during Storm periods (N = 10)
DROP VIEW IF EXISTS v_top_crime_types_storm;
CREATE VIEW v_top_crime_types_storm AS
SELECT crime_activity, event_count
FROM (
  SELECT
    ct.crime_activity,
    COUNT(*) AS event_count,
    DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
  FROM event e
  JOIN crime_type ct ON ct.crime_type_id = e.crime_type_id
  WHERE e.storm_flag = 1
  GROUP BY ct.crime_activity
) t
WHERE rnk <= 10
ORDER BY event_count DESC, crime_activity;

-- Monthly heatmap for the top 10 storm crime types
DROP VIEW IF EXISTS v_monthly_top10_crimetypes_heatmap;
CREATE VIEW v_monthly_top10_crimetypes_heatmap AS
SELECT
  DATE_FORMAT(e.event_date, '%Y-%m') AS yyyymm,
  ct.crime_activity,
  COUNT(*) AS event_count
FROM event e
JOIN crime_type ct ON ct.crime_type_id = e.crime_type_id
JOIN v_top_crime_types_storm t10 ON t10.crime_activity = ct.crime_activity
GROUP BY yyyymm, ct.crime_activity
ORDER BY yyyymm, event_count DESC;

-- Optional: refresh the materialized monthly table from the view
DROP TABLE IF EXISTS monthly_crime_counts_temp;
CREATE TABLE monthly_crime_counts_temp AS
SELECT * FROM v_monthly_event_counts;

REPLACE INTO monthly_crime_counts (period_date, storm_flag, event_count, source)
SELECT period_date, storm_flag, event_count, 'derived_from_events'
FROM monthly_crime_counts_temp;
