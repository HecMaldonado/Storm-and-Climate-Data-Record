# src/analyze_types_mysql.R
suppressPackageStartupMessages({
  library(DBI)
  library(RMariaDB)
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(tidyr)
  library(viridis)
})

# Output dirs
out_dir <- "output"
fig_dir <- file.path("docs","figures")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Connect to MySQL
con <- dbConnect(
  RMariaDB::MariaDB(),
  host = "127.0.0.1",
  port = 3306,
  user = "scdr_user",        # change to your user
  password = "your_password",
  dbname = "scdr"
)

on.exit(dbDisconnect(con), add = TRUE)

# Pull data from views
monthly <- dbGetQuery(con, "SELECT * FROM v_combined_monthly_event_counts")
daily   <- dbGetQuery(con, "SELECT * FROM v_cumulative_event_counts_daily")
types   <- dbGetQuery(con, "SELECT * FROM v_crime_type_counts_by_storm")
top10   <- dbGetQuery(con, "SELECT * FROM v_top_crime_types_storm")
heatmap <- dbGetQuery(con, "SELECT * FROM v_monthly_top10_crimetypes_heatmap")

# 1) combined_monthly_event_counts.csv
readr::write_csv(monthly, file.path(out_dir, "combined_monthly_event_counts.csv"))

# 2) cumulative_event_counts.png
p_cum <- ggplot(monthly, aes(x = as.Date(period_date), y = cum_event_count, color = storm_flag)) +
  geom_line(size = 1.2) +
  scale_color_manual(values = c("Storm" = "#17BECF", "No Storm" = "#FF6B6B")) +
  labs(title = "Cumulative Crime Events by Storm Status",
       subtitle = "Source: MySQL v_combined_monthly_event_counts",
       x = "Month", y = "Cumulative Count", color = "Storm Status") +
  theme_minimal(base_size = 12)

ggsave(file.path(out_dir, "cumulative_event_counts.png"), plot = p_cum, width = 10, height = 6, dpi = 150)
ggsave(file.path(fig_dir, "cumulative_event_counts.png"), plot = p_cum, width = 10, height = 6, dpi = 150)

# 3) crime_type_counts_by_storm.csv
readr::write_csv(types, file.path(out_dir, "crime_type_counts_by_storm.csv"))

# 4) top_crime_types_storm.csv and .png
readr::write_csv(top10, file.path(out_dir, "top_crime_types_storm.csv"))

p_top <- ggplot(top10, aes(x = reorder(crime_activity, event_count), y = event_count)) +
  geom_col(fill = "#17BECF") +
  coord_flip() +
  labs(title = "Top Crime Types During Storm Events", x = "Crime Type", y = "Event Count") +
  theme_minimal(base_size = 12)

ggsave(file.path(out_dir, "top_crime_types_storm.png"), plot = p_top, width = 10, height = 6, dpi = 150)
ggsave(file.path(fig_dir, "top_crime_types_storm.png"), plot = p_top, width = 10, height = 6, dpi = 150)

# 5) monthly_top10_crimetypes_heatmap.png (+ data CSV)
heat <- heatmap %>%
  mutate(period_date = as.Date(paste0(yyyymm, "-01"))) %>%
  select(period_date, crime_activity, event_count)

# Complete the grid for all months x top10 categories
heat_completed <- heat %>%
  tidyr::complete(
    period_date = seq(min(period_date), max(period_date), by = "month"),
    crime_activity = unique(crime_activity),
    fill = list(event_count = 0)
  )

readr::write_csv(heat_completed %>% arrange(period_date, crime_activity),
                 file.path(out_dir, "monthly_top10_crimetypes_heatmap_data.csv"))

p_heat <- ggplot(heat_completed, aes(x = period_date, y = crime_activity, fill = event_count)) +
  geom_tile() +
  scale_fill_viridis_c(option = "magma") +
  labs(title = "Monthly Counts for Top 10 Crime Types (Storm Periods)",
       x = "Month", y = "Crime Type", fill = "Count") +
  theme_minimal(base_size = 10)

ggsave(file.path(out_dir, "monthly_top10_crimetypes_heatmap.png"), plot = p_heat, width = 12, height = 6, dpi = 150)
ggsave(file.path(fig_dir, "monthly_top10_crimetypes_heatmap.png"), plot = p_heat, width = 12, height = 6, dpi = 150)
