-- queries.sql
USE scdr;

-- Sanity checks
SELECT COUNT(*) AS total_events FROM storm_crimes;
SELECT MIN(event_date) AS min_date, MAX(event_date) AS max_date FROM storm_crimes;

-- Create a view that flags storm vs no-storm (storm_activity non-empty => Storm)
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

-- Monthly aggregation (counts) from the event-level data
DROP TABLE IF EXISTS monthly_event_counts_temp;
CREATE TABLE monthly_event_counts_temp AS
SELECT
  STR_TO_DATE(DATE_FORMAT(event_date, '%Y-%m-01'), '%Y-%m-%d') AS period_date,
  CASE WHEN TRIM(IFNULL(storm_activity,'')) = '' THEN 'No Storm' ELSE 'Storm' END AS storm_flag,
  COUNT(*) AS event_count
FROM storm_crimes
GROUP BY period_date, storm_flag
ORDER BY period_date, storm_flag;

-- Copy aggregated temp into the canonical monthly_event_counts table (insert or replace)
REPLACE INTO monthly_event_counts (period_date, storm_flag, event_count, source)
SELECT period_date, storm_flag, event_count, 'derived_from_events' FROM monthly_event_counts_temp;

-- Cumulative counts by storm_flag (ordered by date)
SELECT 
  period_date,
  storm_flag,
  event_count,
  @cum := IF(@prev_flag = storm_flag, @cum + event_count, event_count) AS cum_event_count,
  @prev_flag := storm_flag
FROM (
  SELECT period_date, storm_flag, event_count
  FROM monthly_event_counts
  ORDER BY storm_flag, period_date
) AS t
CROSS JOIN (SELECT @cum := 0, @prev_flag := '') vars;

-- Top crime activities during storms
SELECT crime_activity, COUNT(*) AS n_events
FROM storm_crimes
WHERE TRIM(IFNULL(storm_activity,'')) <> ''
GROUP BY crime_activity
ORDER BY n_events DESC
LIMIT 25;

-- Counts by city and storm type
SELECT city, CASE WHEN TRIM(IFNULL(storm_activity,'')) = '' THEN 'No Storm' ELSE 'Storm' END AS storm_flag, COUNT(*) AS n_events
FROM storm_crimes
GROUP BY city, storm_flag
ORDER BY city, n_events DESC
LIMIT 200;

-- Optional: export monthly_event_counts to CSV (server must allow INTO OUTFILE)
SELECT period_date, storm_flag, event_count
INTO OUTFILE '/var/lib/mysql-files/monthly_event_counts.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
FROM monthly_event_counts
ORDER BY period_date, storm_flag;
