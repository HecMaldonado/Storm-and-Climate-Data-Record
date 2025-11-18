-- schema.sql
CREATE DATABASE IF NOT EXISTS scdr
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
USE scdr;

-- STAGING (mirror file headers; load here first)
CREATE TABLE IF NOT EXISTS staging_storm_crimes (
  id VARCHAR(64),
  date_raw VARCHAR(20),            -- MM/DD/YYYY expected
  crimeactivity VARCHAR(255),
  stormactivity VARCHAR(255),
  zone VARCHAR(120),
  city VARCHAR(120),
  zonecityid VARCHAR(64)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS staging_module_six (
  event_id VARCHAR(64),
  crime_type VARCHAR(255),
  crime_code INT,
  city VARCHAR(120),
  city_code INT,
  date_of_crime_raw VARCHAR(20),   -- will parse from raw text or serial
  zone VARCHAR(120),
  zonecityid VARCHAR(64)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- DIMENSIONS
CREATE TABLE IF NOT EXISTS crime_type (
  crime_type_id INT AUTO_INCREMENT PRIMARY KEY,
  crime_activity VARCHAR(255) NOT NULL,
  UNIQUE KEY uq_crime_activity (crime_activity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS zone (
  zone_id INT AUTO_INCREMENT PRIMARY KEY,
  zone VARCHAR(120) NOT NULL DEFAULT '',
  city VARCHAR(120) NOT NULL DEFAULT '',
  zone_city_id VARCHAR(64) NOT NULL DEFAULT '',
  UNIQUE KEY uq_zone (zone, city, zone_city_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- FACT: one row per crime event
-- storm_flag: 1 = Storm, 0 = No Storm
CREATE TABLE IF NOT EXISTS event (
  event_id VARCHAR(64) NOT NULL PRIMARY KEY,
  event_date DATE NOT NULL,
  crime_type_id INT NOT NULL,
  storm_flag TINYINT(1) NOT NULL,
  zone_id INT NULL,
  source VARCHAR(40) NOT NULL DEFAULT 'storm_csv',
  CONSTRAINT fk_event_crime_type FOREIGN KEY (crime_type_id) REFERENCES crime_type (crime_type_id),
  CONSTRAINT fk_event_zone       FOREIGN KEY (zone_id)       REFERENCES zone (zone_id),
  KEY idx_event_date (event_date),
  KEY idx_storm_flag_date (storm_flag, event_date),
  KEY idx_crime_type (crime_type_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Optional materialized table (you can also rely on views)
CREATE TABLE IF NOT EXISTS monthly_crime_counts (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  period_date DATE NOT NULL,
  storm_flag ENUM('Storm','No Storm') NOT NULL,
  event_count INT NOT NULL,
  source VARCHAR(64) NULL,
  UNIQUE KEY ux_period_flag (period_date, storm_flag),
  INDEX idx_period (period_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
