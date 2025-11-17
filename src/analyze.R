# src/analyze.R
# SCDR — Cumulative crime Loss by Storm status (Jan 2017 - Dec 2019)
# Expects data/crimestormQ.csv and data/crimenostormQ.csv (monthly rows).
#
# Usage:
#  - Put input CSVs in data/
#  - Run in R or RStudio: source("src/analyze.R")

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(lubridate)
})

# Paths
storm_path   <- file.path("data", "crimestormQ.csv")
nostorm_path <- file.path("data", "crimenostormQ.csv")
out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Read helper that is case-tolerant for column names
safe_read <- function(path) {
  df <- read_csv(path, show_col_types = FALSE)
  names(df) <- tolower(names(df))
  return(df)
}

storm_df <- safe_read(storm_path)
nostorm_df <- safe_read(nostorm_path)

# Determine date column (if present) and loss column
find_date_col <- function(df) {
  cand <- intersect(c("date", "period_date", "period", "month"), names(df))
  if (length(cand) >= 1) return(cand[1]) else return(NA)
}
find_loss_col <- function(df) {
  cand <- intersect(c("loss", "loss_usd", "amount", "value"), names(df))
  if (length(cand) >= 1) return(cand[1]) else return(NA)
}

# Add Date column if needed (assume monthly starting 2017-01-01)
ensure_date_and_loss <- function(df, default_start = as.Date("2017-01-01")) {
  date_col <- find_date_col(df)
  loss_col <- find_loss_col(df)
  if (is.na(loss_col)) stop("No loss column found in data; expected column name 'loss' or similar.")
  # Date
  if (!is.na(date_col)) {
    df <- df %>% mutate(date = as.Date(get(date_col)))
    # If parsing yields NA, try other common formats
    if (all(is.na(df$date)) && inherits(get(date_col), "character")) {
      df <- df %>% mutate(date = parse_date_time( get(date_col), orders = c("Y-m-d","m/d/Y","Y/%m/%d") ))
    }
  } else {
    df <- df %>% mutate(date = seq(default_start, by = "month", length.out = nrow(.)))
  }
  # Loss -> numeric
  df <- df %>% mutate(loss = as.numeric(get(loss_col)))
  if (any(is.na(df$loss))) stop("Some loss values could not be converted to numeric. Check input files.")
  return(df %>% select(date, loss, everything()))
}

storm_df <- ensure_date_and_loss(storm_df, default_start = as.Date("2017-01-01"))
nostorm_df <- ensure_date_and_loss(nostorm_df, default_start = as.Date("2017-01-01"))

# Label and combine
storm_df <- storm_df %>% mutate(storm_status = "Storm")
nostorm_df <- nostorm_df %>% mutate(storm_status = "No Storm")
combined <- bind_rows(storm_df %>% select(date, loss, storm_status),
                      nostorm_df %>% select(date, loss, storm_status))

# Validation checks (expected period Jan 2017 through Dec 2019 per project)
stopifnot(min(combined$date, na.rm = TRUE) >= as.Date("2017-01-01") - 1)
stopifnot(max(combined$date, na.rm = TRUE) <= as.Date("2019-12-31") + 1)

# Compute cumulative loss by storm_status (in thousands USD)
combined <- combined %>%
  arrange(storm_status, date) %>%
  group_by(storm_status) %>%
  mutate(cum_loss_k = cumsum(loss) / 1000) %>%
  ungroup()

# Save combined summary
write_csv(combined, file.path(out_dir, "combined_monthly_losses.csv"))

# Plot
p <- ggplot(combined, aes(x = date, y = cum_loss_k, color = storm_status)) +
  geom_line(size = 1.1) +
  scale_color_manual(values = c("Storm" = "#17BECF", "No Storm" = "#FF6B6B")) +
  labs(
    title = "Victim Loss From Crimes for Jan 2017 - Dec 2019",
    subtitle = "Cumulative Loss in Thousands of Dollars",
    x = "By Month by Year",
    y = "Victim Loss (K$)",
    color = "Crime Condition",
    caption = "Data: crimestormQ.csv and crimenostormQ.csv"
  ) +
  theme_minimal(base_size = 12)

# Save
ggsave(filename = file.path(out_dir, "cumulative_losses.png"), plot = p, width = 10, height = 6, dpi = 150)

message("Analysis complete. Outputs written to: ", out_dir)
