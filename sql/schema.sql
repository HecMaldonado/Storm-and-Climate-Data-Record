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


Storm-and-Climate-Data-Record/sql/queries.sql:
-- queries.sql
USE scdr;

-- Sanity checks
SELECT COUNT(*) AS total_events, MIN(event_date) AS min_date, MAX(event_date) AS max_date FROM storm_crimes;

-- View: label Storm vs No Storm
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

-- Crime type counts overall and during storms
SELECT
  crime_activity,
  CASE WHEN TRIM(IFNULL(storm_activity,'')) = '' THEN 'No Storm' ELSE 'Storm' END AS storm_flag,
  COUNT(*) AS n_events
FROM storm_crimes
GROUP BY crime_activity, storm_flag
ORDER BY storm_flag, n_events DESC;

-- Top N crime types during Storm periods
SELECT crime_activity, COUNT(*) AS n_events
FROM storm_crimes
WHERE TRIM(IFNULL(storm_activity,'')) <> ''
GROUP BY crime_activity
ORDER BY n_events DESC
LIMIT 25;

-- Monthly counts by storm_flag (materialize)
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

Storm-and-Climate-Data-Record/sql/load_data.sql:
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

Storm-and-Climate-Data-Record/src/analyze.R:
# src/analyze_types.R
# Updated to read:
#  - data/StormCrimes_TrulyCleaned.csv
#  - data/DAT 375 Module Six Assignment Data Set*.xlsx  (auto-detects file starting with "DAT 375 Module Six")
# Produces CSVs and PNGs in output/ and copies PNGs to docs/figures/

suppressPackageStartupMessages({
  library(readr)
  library(readxl)
  library(dplyr)
  library(lubridate)
  library(ggplot2)
  library(tidyr)
  library(viridis)
})

# Paths
storm_csv <- file.path("data", "StormCrimes_TrulyCleaned.csv")

# Auto-detect Module Six Excel file (supports variants like "... COMPLETE.xlsx")
module6_files <- list.files("data", pattern = "^DAT 375 Module Six", full.names = TRUE)
module6_xlsx <- if (length(module6_files) >= 1) module6_files[1] else NA
module6_sheet_name <- "Crime data 2019"  # expected sheet; fallback to first sheet

out_dir <- "output"
fig_dir <- file.path("docs", "figures")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Helper: normalize column names to simple lower_snake
norm_names <- function(df) {
  names(df) <- names(df) %>%
    gsub("\\s+", "_", .) %>%
    gsub("[^A-Za-z0-9_]", "", .) %>%
    tolower()
  df
}

# ---------- Read StormCrimes_TrulyCleaned.csv ----------
if (!file.exists(storm_csv)) stop("Missing file: data/StormCrimes_TrulyCleaned.csv")
storm <- read_csv(storm_csv, show_col_types = FALSE)
storm <- norm_names(storm)

# Ensure date column exists and parse (Storm file uses MM/DD/YYYY)
if ("date" %in% names(storm)) {
  storm <- storm %>% mutate(event_date = as.Date(date, format = "%m/%d/%Y"))
} else {
  stop("Storm file missing 'Date' column (expected column name 'Date').")
}
if (any(is.na(storm$event_date))) {
  # try alternative parsing
  storm <- storm %>% mutate(event_date = parse_date_time(date, orders = c("mdy","ymd","Y-m-d")))
  storm$event_date <- as.Date(storm$event_date)
}

# Normalize crime_activity and storm_activity fields
if ("crimeactivity" %in% names(storm)) storm$crime_activity <- as.character(storm$crimeactivity)
if ("crime_activity" %in% names(storm)) storm$crime_activity <- as.character(storm$crime_activity)
if ("stormactivity" %in% names(storm)) storm$storm_activity <- as.character(storm$stormactivity)
if ("storm_activity" %in% names(storm)) storm$storm_activity <- as.character(storm$storm_activity)

storm <- storm %>%
  mutate(
    crime_activity = ifelse(is.na(crime_activity), "", crime_activity),
    storm_activity = ifelse(is.na(storm_activity), "", storm_activity),
    storm_flag = ifelse(trimws(coalesce(storm_activity, "")) == "", "No Storm", "Storm")
  )

# ---------- Read Module Six Excel (if present) ----------
module6 <- NULL
if (!is.na(module6_xlsx) && file.exists(module6_xlsx)) {
  # choose sheet: try named sheet first, then fallback to first sheet
  sheets <- excel_sheets(module6_xlsx)
  sheet_to_read <- if (module6_sheet_name %in% sheets) module6_sheet_name else sheets[1]
  module6 <- read_xlsx(module6_xlsx, sheet = sheet_to_read)
  module6 <- as.data.frame(module6)
  module6 <- norm_names(module6)
  # map crime type column
  if ("crime_type" %in% names(module6)) {
    module6$crime_activity <- as.character(module6$crime_type)
  } else if ("crime" %in% names(module6)) {
    module6$crime_activity <- as.character(module6$crime)
  } else {
    # try other likely names
    possible <- intersect(c("crime_type","crime_type_1","crime_type_2019","crime"), names(module6))
    if (length(possible)) module6$crime_activity <- as.character(module6[[possible[1]]]) else module6$crime_activity <- ""
  }
  # parse module dates (Date of crime or similar). handle Excel serials
  date_col <- intersect(c("date_of_crime","date","dateofcrime","date_of_crime_1"), names(module6))
  if (length(date_col) >= 1) {
    dcol <- date_col[1]
    # attempt standard date parse
    parsed <- suppressWarnings(as.Date(module6[[dcol]]))
    if (all(is.na(parsed))) {
      # try numeric Excel serial origin
      numeric_vals <- suppressWarnings(as.numeric(module6[[dcol]]))
      if (any(!is.na(numeric_vals))) {
        parsed2 <- as.Date(numeric_vals, origin = "1899-12-30")
        module6$event_date <- parsed2
      } else {
        module6$event_date <- NA
      }
    } else {
      module6$event_date <- parsed
    }
  } else {
    module6$event_date <- NA
  }
  # ensure crime_activity exists
  module6$crime_activity <- ifelse(is.na(module6$crime_activity), "", module6$crime_activity)
} else {
  message("Module Six Excel not found in data/ (file starting with 'DAT 375 Module Six'). Proceeding without it.")
}

# ---------- ANALYSES ----------

# 1) combined_monthly_event_counts.csv (from storm file)
monthly_counts <- storm %>%
  mutate(period_date = floor_date(event_date, "month")) %>%
  group_by(period_date, storm_flag) %>%
  summarise(event_count = n(), .groups = "drop") %>%
  arrange(storm_flag, period_date) %>%
  group_by(storm_flag) %>%
  mutate(cum_event_count = cumsum(event_count)) %>%
  ungroup()

write_csv(monthly_counts, file.path(out_dir, "combined_monthly_event_counts.csv"))

# 2) cumulative_event_counts.png
p_cum <- ggplot(monthly_counts, aes(x = period_date, y = cum_event_count, color = storm_flag)) +
  geom_line(size = 1.2, na.rm = TRUE) +
  scale_color_manual(values = c("Storm" = "#17BECF", "No Storm" = "#FF6B6B")) +
  labs(title = "Cumulative Crime Events by Storm Status",
       subtitle = "Derived from StormCrimes_TrulyCleaned.csv",
       x = "Month", y = "Cumulative Event Count", color = "Storm Status") +
  theme_minimal(base_size = 12)

ggsave(file.path(out_dir, "cumulative_event_counts.png"), plot = p_cum, width = 10, height = 6, dpi = 150)
ggsave(file.path(fig_dir, "cumulative_event_counts.png"), plot = p_cum, width = 10, height = 6, dpi = 150)

# 3) crime_type_counts_by_storm.csv
crime_type_by_storm <- storm %>%
  group_by(crime_activity, storm_flag) %>%
  summarise(n_events = n(), .groups = "drop") %>%
  arrange(storm_flag, desc(n_events))

write_csv(crime_type_by_storm, file.path(out_dir, "crime_type_counts_by_storm.csv"))

# 4) top_crime_types_storm.png & CSV
top_storm_crimes <- crime_type_by_storm %>%
  filter(storm_flag == "Storm") %>%
  arrange(desc(n_events)) %>%
  slice_head(n = 20)

write_csv(top_storm_crimes, file.path(out_dir, "top_crime_types_storm.csv"))

p_top <- ggplot(top_storm_crimes, aes(x = reorder(crime_activity, n_events), y = n_events)) +
  geom_col(fill = "#17BECF") +
  coord_flip() +
  labs(title = "Top Crime Types During Storm Events", x = "Crime Type", y = "Event Count") +
  theme_minimal(base_size = 12)

ggsave(file.path(out_dir, "top_crime_types_storm.png"), plot = p_top, width = 10, height = 6, dpi = 150)
ggsave(file.path(fig_dir, "top_crime_types_storm.png"), plot = p_top, width = 10, height = 6, dpi = 150)

# 5) monthly_top10_crimetypes_heatmap.png (uses combined data if module6 present, else storm only)
if (!is.null(module6)) {
  combined_for_top <- bind_rows(
    storm %>% select(event_date, crime_activity),
    module6 %>% select(event_date, crime_activity)
  )
} else {
  combined_for_top <- storm %>% select(event_date, crime_activity)
}

top10 <- combined_for_top %>%
  filter(!is.na(crime_activity) & crime_activity != "") %>%
  count(crime_activity, sort = TRUE) %>% slice_head(n = 10) %>% pull(crime_activity)

heat <- combined_for_top %>%
  filter(crime_activity %in% top10) %>%
  mutate(period_date = floor_date(event_date, "month")) %>%
  count(period_date, crime_activity) %>%
  complete(period_date = seq(min(period_date, na.rm = TRUE), max(period_date, na.rm = TRUE), by = "month"),
           crime_activity = top10,
           fill = list(n = 0))

write_csv(heat %>% arrange(period_date, crime_activity), file.path(out_dir, "monthly_top10_crimetypes_heatmap_data.csv"))

p_heat <- ggplot(heat, aes(x = period_date, y = crime_activity, fill = n)) +
  geom_tile() +
  scale_fill_viridis_c(option = "magma") +
  labs(title = "Monthly Counts for Top 10 Crime Types", x = "Month", y = "Crime Type", fill = "Count") +
  theme_minimal(base_size = 10)

ggsave(file.path(out_dir, "monthly_top10_crimetypes_heatmap.png"), plot = p_heat, width = 12, height = 6, dpi = 150)
ggsave(file.path(fig_dir, "monthly_top10_crimetypes_heatmap.png"), plot = p_heat, width = 12, height = 6, dpi = 150)

message("Outputs written to: ", normalizePath(out_dir), " and figures copied to: ", normalizePath(fig_dir))
