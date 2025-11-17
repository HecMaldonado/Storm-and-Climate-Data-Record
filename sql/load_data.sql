-- load_data.sql
USE scdr;

-- 1) Load event-level raw CSV (StormCrimesRaw.csv)
LOAD DATA LOCAL INFILE 'data/StormCrimesRaw.csv'
INTO TABLE storm_crimes
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@id, @Date, @CrimeEventID, @CrimeActivity, @StormEventID, @StormActivity, @ZoneCityID, @Zone, @City)
SET
  id = CAST(NULLIF(TRIM(@id),'') AS UNSIGNED),
  event_date = STR_TO_DATE(NULLIF(@Date,''), '%m/%d/%Y'),
  crime_event_id = NULLIF(TRIM(REPLACE(@CrimeEventID, '.0', '')), '') + 0,
  crime_activity = NULLIF(@CrimeActivity, ''),
  storm_event_id = NULLIF(TRIM(@StormEventID), '') + 0,
  storm_activity = NULLIF(@StormActivity, ''),
  zone_city_id = NULLIF(TRIM(@ZoneCityID), '') + 0,
  zone = NULLIF(@Zone, ''),
  city = NULLIF(@City, '');

-- 2) Load a pre-cleaned event file (if you have StormRimes_Cleaned.csv or similar)
-- Note: adjust fields/order if the cleaned file columns differ
LOAD DATA LOCAL INFILE 'data/StormRimes_Cleaned.csv'
INTO TABLE storm_crimes_cleaned
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@id, @Date, @CrimeEventID, @CrimeActivity, @StormEventID, @StormActivity, @ZoneCityID, @Zone, @City)
SET
  id = CAST(NULLIF(TRIM(@id),'') AS UNSIGNED),
  event_date = STR_TO_DATE(NULLIF(@Date,''), '%m/%d/%Y'),
  crime_event_id = NULLIF(TRIM(REPLACE(@CrimeEventID, '.0', '')), '') + 0,
  crime_activity = NULLIF(@CrimeActivity, ''),
  storm_event_id = NULLIF(TRIM(@StormEventID), '') + 0,
  storm_activity = NULLIF(@StormActivity, ''),
  zone_city_id = NULLIF(TRIM(@ZoneCityID), '') + 0,
  zone = NULLIF(@Zone, ''),
  city = NULLIF(@City, '');

-- 3) If you have monthly files (crimestormQ.csv / crimenostormQ.csv), load them into monthly_losses:
LOAD DATA LOCAL INFILE 'data/crimestormQ.csv'
INTO TABLE monthly_losses
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@date_str, @loss)
SET period_date = STR_TO_DATE(NULLIF(@date_str,''), '%Y-%m-%d'),
    loss_usd = CAST(NULLIF(@loss,'') AS DECIMAL(12,2)),
    storm_flag = 'Storm',
    source_file = 'crimestormQ.csv';

LOAD DATA LOCAL INFILE 'data/crimenostormQ.csv'
INTO TABLE monthly_losses
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@date_str, @loss)
SET period_date = STR_TO_DATE(NULLIF(@date_str,''), '%Y-%m-%d'),
    loss_usd = CAST(NULLIF(@loss,'') AS DECIMAL(12,2)),
    storm_flag = 'No Storm',
    source_file = 'crimenostormQ.csv';

