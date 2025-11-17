-- load_data.sql
USE scdr;

LOAD DATA LOCAL INFILE 'data/StormCrimes_TrulyCleaned.csv'
INTO TABLE storm_crimes
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@id, @Date, @CrimeEventID, @CrimeActivity, @StormEventID, @StormActivity, @ZoneCityID, @Zone, @City)
SET
  id = CAST(@id AS UNSIGNED),
  event_date = STR_TO_DATE(@Date, '%m/%d/%Y'),
  crime_event_id = NULLIF(TRIM(REPLACE(@CrimeEventID, '.0', '')), '') + 0,
  crime_activity = NULLIF(@CrimeActivity, ''),
  storm_event_id = NULLIF(TRIM(@StormEventID), '') + 0,
  storm_activity = NULLIF(@StormActivity, ''),
  zone_city_id = NULLIF(TRIM(@ZoneCityID), '') + 0,
  zone = NULLIF(@Zone, ''),
  city = NULLIF(@City, '');

-- Export module six sheet to CSV first (module_six_crimes.csv), then:
LOAD DATA LOCAL INFILE 'data/module_six_crimes.csv'
INTO TABLE module_six_crimes
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@unnamed, @Event_ID, @Crime_type, @Crime_Code, @City, @City_Code, @Date_of_crime)
SET
  event_id = NULLIF(@Event_ID,''),
  crime_type = NULLIF(@Crime_type,''),
  crime_code = NULLIF(@Crime_Code,'') + 0,
  city = NULLIF(@City,''),
  city_code = NULLIF(@City_Code,'') + 0,
  date_of_crime = STR_TO_DATE(@Date_of_crime, '%Y-%m-%d');
