-- load_data.sql
USE scdr;

-- Ensure connection uses utf8mb4 when loading (avoid legacy utf8) [[3]]
SET NAMES utf8mb4;

-- 1) Clear staging (safe re-loads)
TRUNCATE TABLE staging_storm_crimes;
TRUNCATE TABLE staging_module_six;

-- 2) Load raw files into staging (adjust paths)
-- Enable LOCAL on client if needed: mysql --local-infile=1
LOAD DATA LOCAL INFILE '/absolute/path/to/data/StormCrimes_TrulyCleaned.csv'
INTO TABLE staging_storm_crimes
FIELDS TERMINATED BY ',' ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, date_raw, crimeactivity, stormactivity, zone, city, zonecityid);

-- Optional Module Six (convert XLSX to CSV first or ingest via ETL)
-- LOAD DATA LOCAL INFILE '/absolute/path/to/data/ModuleSixCrimeData2019.csv'
-- INTO TABLE staging_module_six
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"' ESCAPED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (event_id, crime_type, crime_code, city, city_code, date_of_crime_raw, zone, zonecityid);

-- 3) Upsert dimensions
INSERT IGNORE INTO crime_type (crime_activity)
SELECT DISTINCT TRIM(crimeactivity)
FROM staging_storm_crimes
WHERE crimeactivity IS NOT NULL AND TRIM(crimeactivity) <> '';

INSERT IGNORE INTO zone (zone, city, zone_city_id)
SELECT
  COALESCE(TRIM(zone),''),
  COALESCE(TRIM(city),''),
  COALESCE(TRIM(zonecityid),'')
FROM staging_storm_crimes;

-- (Optional) include Module Six dimension members
INSERT IGNORE INTO crime_type (crime_activity)
SELECT DISTINCT TRIM(crime_type)
FROM staging_module_six
WHERE crime_type IS NOT NULL AND TRIM(crime_type) <> '';

INSERT IGNORE INTO zone (zone, city, zone_city_id)
SELECT
  COALESCE(TRIM(zone),''),
  COALESCE(TRIM(city),''),
  COALESCE(TRIM(zonecityid),'')
FROM staging_module_six;

-- 4) Populate fact table from staging_storm_crimes
-- Note: event_id uses raw id; date parsed from MM/DD/YYYY
INSERT INTO event (event_id, event_date, crime_type_id, storm_flag, zone_id, source)
SELECT
  TRIM(s.id) AS event_id,
  STR_TO_DATE(s.date_raw, '%m/%d/%Y') AS event_date,
  ct.crime_type_id,
  CASE WHEN NULLIF(TRIM(s.stormactivity),'') IS NULL THEN 0 ELSE 1 END AS storm_flag,
  z.zone_id,
  'storm_csv' AS source
FROM staging_storm_crimes s
JOIN crime_type ct ON ct.crime_activity = TRIM(s.crimeactivity)
LEFT JOIN zone z
  ON z.zone = COALESCE(TRIM(s.zone),'')
 AND z.city = COALESCE(TRIM(s.city),'')
 AND z.zone_city_id = COALESCE(TRIM(s.zonecityid),'')
ON DUPLICATE KEY UPDATE
  event_date = VALUES(event_date),
  crime_type_id = VALUES(crime_type_id),
  storm_flag = VALUES(storm_flag),
  zone_id = VALUES(zone_id),
  source = VALUES(source);

-- 5) (Optional) Integrate Module Six rows (no explicit storm flag; set 0)
INSERT INTO event (event_id, event_date, crime_type_id, storm_flag, zone_id, source)
SELECT
  TRIM(m.event_id) AS event_id,
  STR_TO_DATE(m.date_of_crime_raw, '%m/%d/%Y') AS event_date,
  ct.crime_type_id,
  0 AS storm_flag,
  z.zone_id,
  'module_six' AS source
FROM staging_module_six m
JOIN crime_type ct ON ct.crime_activity = TRIM(m.crime_type)
LEFT JOIN zone z
  ON z.zone = COALESCE(TRIM(m.zone),'')
 AND z.city = COALESCE(TRIM(m.city),'')
 AND z.zone_city_id = COALESCE(TRIM(m.zonecityid),'')
ON DUPLICATE KEY UPDATE
  event_date = VALUES(event_date),
  crime_type_id = VALUES(crime_type_id),
  zone_id = VALUES(zone_id),
  source = VALUES(source);

-- 6) Optional: refresh materialized monthly counts
DROP TABLE IF EXISTS monthly_crime_counts_temp;
CREATE TABLE monthly_crime_counts_temp AS
SELECT
  STR_TO_DATE(DATE_FORMAT(e.event_date, '%Y-%m-01'), '%Y-%m-%d') AS period_date,
  CASE WHEN e.storm_flag = 1 THEN 'Storm' ELSE 'No Storm' END AS storm_flag,
  COUNT(*) AS event_count
FROM event e
GROUP BY period_date, storm_flag;

REPLACE INTO monthly_crime_counts (period_date, storm_flag, event_count, source)
SELECT period_date, storm_flag, event_count, 'derived_from_events'
FROM monthly_crime_counts_temp;
