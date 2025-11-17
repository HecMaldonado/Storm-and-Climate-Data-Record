# src/analyze_types.R
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(lubridate)
  library(ggplot2)
  library(tidyr)
})

# Paths
storm_csv <- file.path("data", "StormCrimes_TrulyCleaned.csv")
module6_csv <- file.path("data", "module_six_crimes.csv")  # optional - export Excel to CSV first
out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Read storm events file
df <- read_csv(storm_csv, show_col_types = FALSE)
# Normalize column names
names(df) <- make.names(names(df), unique = TRUE)

# Parse date (CSV uses m/d/Y)
if ("Date" %in% names(df)) {
  df <- df %>% mutate(event_date = as.Date(Date, format = "%m/%d/%Y"))
} else {
  stop("Date column not found in StormCrimes_TrulyCleaned.csv")
}
stopifnot(!any(is.na(df$event_date)))

# Standardize fields
df <- df %>% mutate(
  crime_activity = as.character(CrimeActivity),
  storm_activity = as.character(StormActivity),
  storm_flag = ifelse(trimws(coalesce(storm_activity, "")) == "", "No Storm", "Storm")
)

# 1) Crime type counts by storm_flag
crime_type_by_storm <- df %>%
  group_by(crime_activity, storm_flag) %>%
  summarise(n_events = n(), .groups = "drop") %>%
  arrange(storm_flag, desc(n_events))

write_csv(crime_type_by_storm, file.path(out_dir, "crime_type_counts_by_storm.csv"))

# 2) Top 20 crimes during Storm periods (CSV + bar chart)
top_storm_crimes <- crime_type_by_storm %>%
  filter(storm_flag == "Storm") %>%
  arrange(desc(n_events)) %>%
  slice_head(n = 20)

write_csv(top_storm_crimes, file.path(out_dir, "top_crime_types_storm.csv"))

p1 <- ggplot(top_storm_crimes, aes(x = reorder(crime_activity, n_events), y = n_events)) +
  geom_col(fill = "#17BECF") +
  coord_flip() +
  labs(title = "Top Crime Types During Storm Events", x = "Crime Type", y = "Event Count") +
  theme_minimal(base_size = 12)
ggsave(filename = file.path(out_dir, "top_crime_types_storm.png"), plot = p1, width = 10, height = 6, dpi = 150)

# 3) Monthly event counts and cumulative counts by Storm/No Storm
monthly_counts <- df %>%
  mutate(period_date = floor_date(event_date, unit = "month")) %>%
  group_by(period_date, storm_flag) %>%
  summarise(event_count = n(), .groups = "drop") %>%
  arrange(storm_flag, period_date) %>%
  group_by(storm_flag) %>%
  mutate(cum_event_count = cumsum(event_count)) %>%
  ungroup()

write_csv(monthly_counts, file.path(out_dir, "combined_monthly_event_counts.csv"))

p2 <- ggplot(monthly_counts, aes(x = period_date, y = cum_event_count, color = storm_flag)) +
  geom_line(size = 1.1) +
  scale_color_manual(values = c("Storm" = "#17BECF", "No Storm" = "#FF6B6B")) +
  labs(title = "Cumulative Crime Events by Storm Status",
       subtitle = "Counts (derived from StormCrimes_TrulyCleaned.csv)",
       x = "Month", y = "Cumulative Event Count", color = "Storm Status") +
  theme_minimal(base_size = 12)

ggsave(filename = file.path(out_dir, "cumulative_event_counts.png"), plot = p2, width = 10, height = 6, dpi = 150)

# 4) Optional: monthly heatmap of top crime types across months
top_overall <- df %>% count(crime_activity, sort = TRUE) %>% slice_head(n = 10) %>% pull(crime_activity)
heat <- df %>%
  filter(crime_activity %in% top_overall) %>%
  mutate(period_date = floor_date(event_date, unit = "month")) %>%
  count(period_date, crime_activity) %>%
  complete(period_date = seq(min(period_date), max(period_date), by = "month"),
           crime_activity = top_overall,
           fill = list(n = 0))

p3 <- ggplot(heat, aes(x = period_date, y = crime_activity, fill = n)) +
  geom_tile() +
  scale_fill_viridis_c(option = "magma") +
  labs(title = "Monthly Counts for Top 10 Crime Types", x = "Month", y = "Crime Type", fill = "Count") +
  theme_minimal(base_size = 10)

ggsave(filename = file.path(out_dir, "monthly_top10_crimetypes_heatmap.png"), plot = p3, width = 12, height = 6, dpi = 150)

message("Outputs written to: ", out_dir)
