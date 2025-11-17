-- queries.sql
USE scdr;

-- 1) Monthly aggregation from event-level (if your raw has loss amounts per event; if not, skip)
-- (Only if your event-level file has a numeric loss column named 'loss_usd')
SELECT
  DATE_FORMAT(event_date, '%Y-%m-01') AS period_date,
  CASE WHEN storm_activity IS NULL OR storm_activity = '' THEN 'No Storm' ELSE 'Storm' END AS storm_flag,
  SUM(loss_usd) AS month_loss
INTO OUTFILE '/tmp/monthly_loss_from_events.csv'
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
FROM storm_crimes
WHERE event_date BETWEEN '2017-01-01' AND '2019-12-31'
GROUP BY period_date, storm_flag
ORDER BY period_date, storm_flag;

-- 2) If you loaded monthly_losses, export aggregated rows with cumulative sums:
SELECT
  period_date,
  storm_flag,
  loss_usd,
  SUM(loss_usd) OVER (PARTITION BY storm_flag ORDER BY period_date) AS cum_loss_usd
FROM monthly_losses
ORDER BY period_date, storm_flag;

-- 3) Aggregate monthly CSV for R (two-row-per-month structure)
SELECT period_date,
       SUM(CASE WHEN storm_flag = 'Storm' THEN loss_usd ELSE 0 END) AS storm_loss,
       SUM(CASE WHEN storm_flag = 'No Storm' THEN loss_usd ELSE 0 END) AS nostorm_loss
FROM monthly_losses
GROUP BY period_date
ORDER BY period_date;

-- 4) Top crime types during Storm events
SELECT crime_activity, COUNT(*) AS n_events
FROM storm_crimes
WHERE storm_activity IS NOT NULL AND storm_activity <> ''
GROUP BY crime_activity
ORDER BY n_events DESC
LIMIT 20;

-- 5) Counts by City and StormActivity
SELECT city, storm_activity, COUNT(*) AS n_events
FROM storm_crimes
GROUP BY city, storm_activity
ORDER BY city, n_events DESC;

