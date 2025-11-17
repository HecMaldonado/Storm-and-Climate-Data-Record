-- schema.sql
CREATE DATABASE IF NOT EXISTS scdr CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
USE scdr;

-- Event-level table (match StormCrimesRaw.csv / StormCrimes_TrulyCleaned.csv)
CREATE TABLE IF NOT EXISTS storm_crimes (
  id BIGINT NOT NULL,
  event_date DATE NOT NULL,
  crime_event_id BIGINT NULL,
  crime_activity VARCHAR(255) NULL,
  storm_event_id BIGINT NULL,
  storm_activity VARCHAR(120) NULL,
  zone_city_id SMALLINT NULL,
  zone VARCHAR(120) NULL,
  city VARCHAR(120) NULL,
  PRIMARY KEY (id),
  INDEX idx_event_date (event_date),
  INDEX idx_storm_activity (storm_activity(60)),
  INDEX idx_crime_activity (crime_activity(60)),
  INDEX idx_city (city)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Optional cleaned event table (if you want to store preprocessed/normalized rows)
CREATE TABLE IF NOT EXISTS storm_crimes_cleaned LIKE storm_crimes;

-- Monthly aggregated losses table (for crimestormQ/crimenostormQ or derived aggregates)
CREATE TABLE IF NOT EXISTS monthly_losses (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  period_date DATE NOT NULL,                 -- first-of-month, e.g. 2017-01-01
  loss_usd DECIMAL(12,2) NOT NULL,
  storm_flag ENUM('Storm','No Storm') NOT NULL,
  source_file VARCHAR(64) NULL,
  UNIQUE KEY ux_period_flag (period_date, storm_flag),
  INDEX idx_period (period_date),
  INDEX idx_storm_flag (storm_flag)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
