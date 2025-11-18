-- sql/queries.sql
USE scdr;

-- Sanity checks
SELECT COUNT(*) AS total_events FROM storm_crimes;
SELECT MIN(event_date) AS min_date, MAX(event_date) AS max_date FROM storm_crimes;

-- View: flag Storm vs No Storm
DROP VIEW IF EXISTS v_events_with_flag;
CREATE VIEW v_events_with_flag AS
SELECT
  id,
  event_date,
  crime_activity,
  storm_activity,
  CASE WHEN TRIM(IFNULL(storm_activity,'')) = '' THEN 'No Storm' ELSE 'Storm' END AS storm_flag,
  city, zone
FROM storm_crimes;

-- Crime type counts by storm_flag (from storm_crimes)
SELECT
  crime_activity,
  CASE WHEN TRIM(IFNULL(storm_activity,'')) = '' THEN 'No Storm' ELSE 'Storm' END AS storm_flag,
  COUNT(*) AS n_events
FROM storm_crimes
GROUP BY crime_activity, storm_flag
ORDER BY storm_flag, n_events DESC;

-- Top 25 crime types during Storm periods
SELECT crime_activity, COUNT(*) AS n_events
FROM storm_crimes
WHERE TRIM(IFNULL(storm_activity,'')) <> ''
GROUP BY crime_activity
ORDER BY n_events DESC
LIMIT 25;

-- Monthly counts derived from storm_crimes
DROP TABLE IF EXISTS monthly_crime_counts_temp;
CREATE TABLE monthly_crime_counts_temp AS
SELECT
  STR_TO_DATE(DATE_FORMAT(event_date, '%Y-%m-01'), '%Y-%m-%d') AS period_date,
  CASE WHEN TRIM(IFNULL(storm_activity,'')) = '' THEN 'No Storm' ELSE 'Storm' END AS storm_flag,
  COUNT(*) AS event_count
FROM storm_crimes
GROUP BY period_date, storm_flag
ORDER BY period_date, storm_flag;

-- Copy into canonical table
REPLACE INTO monthly_crime_counts (period_date, storm_flag, event_count, source)
SELECT period_date, storm_flag, event_count, 'derived_from_events' FROM monthly_crime_counts_temp;
