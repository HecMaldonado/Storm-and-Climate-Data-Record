-- schema.sql
CREATE DATABASE IF NOT EXISTS scdr CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
USE scdr;

CREATE TABLE IF NOT EXISTS storm_crimes (
  id INT UNSIGNED NOT NULL,
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
  INDEX idx_crime_activity (crime_activity(60))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS module_six_crimes (
  row_id INT AUTO_INCREMENT PRIMARY KEY,
  event_id VARCHAR(64),
  crime_type VARCHAR(255),
  crime_code INT,
  city VARCHAR(120),
  city_code INT,
  date_of_crime DATE,
  INDEX idx_module6_date (date_of_crime),
  INDEX idx_module6_city (city)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS monthly_crime_counts (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  period_date DATE NOT NULL,
  storm_flag ENUM('Storm','No Storm') NOT NULL,
  event_count INT NOT NULL,
  source VARCHAR(64) NULL,
  UNIQUE KEY ux_period_flag (period_date, storm_flag),
  INDEX idx_period (period_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
