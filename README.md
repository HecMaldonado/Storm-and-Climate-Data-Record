# 🌩️ Storm & Climate Data Record (SCDR) — Crime Types & Counts (Miami, 2019)

[![R](https://img.shields.io/badge/R-Data%20Analysis-blue.svg)](https://www.r-project.org/)
![Status](https://img.shields.io/badge/status-experimental-orange.svg)

#### ⭐ Summary
- Quick, reproducible analysis of event-level crime records to show which crime types occurred during storm-related activity in Miami (primary sample: Oct 2019).
- Produces CSV summaries and PNG figures: monthly/daily cumulative counts, top-crime bar charts, and a monthly heatmap.
- Event-type/count analysis only — no monetary-loss fields.

#### ▶️ Quick Demo
- After running the analysis (see Quickstart), you should see figures in `docs/figures/` (and `output/`):
  - `docs/figures/cumulative_event_counts.png`
  - `docs/figures/top_crime_types_storm.png`
  - `docs/figures/monthly_top10_crimetypes_heatmap.png`

If an image is missing, run the script using the steps below.

#### ▶️ Quickstart (copy/paste)
1) Clone the repo and change directory:
```bash
git clone https://github.com/HecMaldonado/Storm-and-Climate-Data-Record
cd Storm-and-Climate-Data-Record
```

2) Put data files into `data/`:
- `data/StormCrimes_TrulyCleaned.csv` (event-level; required)
- `data/DAT 375 Module Six Assignment Data Set COMPLETE.xlsx` (optional; sheet: "Crime data 2019")

3) Install required R packages (one-time):
```r
install.packages(c(
  "readr","readxl","dplyr","lubridate","ggplot2","tidyr","viridis","scales"
))
```

4) Run the analysis:
```bash
Rscript src/analyze_types.R
```

5) View outputs:
- CSVs and PNGs in `output/`
- PNG copies also saved to `docs/figures/` for GitHub Pages

#### 📁 Repository Layout (key files)
- `data/` — source files
  - `StormCrimes_TrulyCleaned.csv` (required)
  - `DAT 375 Module Six Assignment Data Set COMPLETE.xlsx` (optional)
- `src/`
  - `analyze_types.R` — main R script (read/normalize/aggregate/plot)
- `sql/` (optional DB helpers)
  - `schema.sql`, `load_data.sql`, `queries.sql`
- `output/` — generated CSVs & PNGs
- `docs/figures/` — images for GitHub Pages
- `docs/index.md` — optional project page

#### 📦 Outputs Produced (what to expect)
- `combined_monthly_event_counts.csv` — period_date, storm_flag, event_count, cum_event_count
- `cumulative_event_counts.png` — canonical cumulative plot (monthly or daily fallback)
- `cumulative_event_counts_daily.png` — daily fallback (when monthly has a single month)
- `crime_type_counts_by_storm.csv` — `crime_activity × storm_flag` counts
- `top_crime_types_storm.csv` and `top_crime_types_storm.png` — top crime types (Storm)
- `monthly_top10_crimetypes_heatmap.png` — heatmap for top-10 crime types

#### 🧭 How the Analysis Works (short)
1) Normalize & parse input files (CSV + optional Module Six sheet).
2) Tag each event: `storm_flag = "Storm"` if `StormActivity` present, otherwise `"No Storm"`.
3) Aggregate counts by month; compute cumulative totals.
4) Fallback: if monthly aggregation has fewer than 2 months, also create a daily cumulative series for visibility.
5) Save CSVs and PNGs to `output/` and copy figures to `docs/figures/`.

#### ❗ Why the Cumulative Plot Can Look “Blank”
- Single-month data: a monthly line plot requires ≥2 distinct months. With only one month (common for the sample), the monthly line may look like a single point.
- Single series present: if all events are labeled Storm (or all No Storm) only one series will plot.
- Script behavior: draws points and numeric labels for single-month series and automatically produces a daily cumulative plot (`cumulative_event_counts_daily.png`) so progression is visible.

#### 🔎 Data Dictionary (core fields)

| Field                           | Source                     | Meaning                                  |
|---------------------------------|----------------------------|------------------------------------------|
| ID                              | Storm CSV                  | Event identifier                          |
| Date / event_date               | Storm CSV                  | Event date (expects MM/DD/YYYY)          |
| CrimeActivity / crime_activity  | Storm CSV / Module Six     | Textual crime category                    |
| StormActivity / storm_activity  | Storm CSV                  | Storm label (empty → No Storm)            |
| Zone, City, ZoneCityID          | Storm CSV                  | Geographic grouping                       |
| Event_ID                        | Module Six                 | Additional event identifier               |
| Crime type                      | Module Six                 | Crime category (used for heatmap)         |
| Date of crime                   | Module Six                 | Event date (used for heatmap)             |

#### 🛠 Troubleshooting (quick)
- File not found: confirm exact filenames and that they are in `data/`.
- Date parse errors: script expects `MM/DD/YYYY` in `StormCrimes_TrulyCleaned.csv` — update parsing in `src/analyze_types.R` if your format differs.
- No “No Storm” series: verify `StormActivity` is blank where appropriate.
- Noisy crime labels: consider normalizing similar labels (a mapping can be added).
- Package install issues: install packages one-by-one or run R/RStudio with elevated permissions.

#### ✅ Next Steps (Future)
- Add a label-normalization map to merge synonymous crime categories.
- Add a GitHub Actions workflow to auto-run the R script on push and publish outputs.
- Build a polished `docs/index.md` landing page with a short narrative and embedded images.

#### ✉️ Contact / Issues
If column names differ or the script errors, open an Issue or contact the repo owner (Hector Maldonado) via the GitHub profile.

Made with ❤️ for the SCDR project.
