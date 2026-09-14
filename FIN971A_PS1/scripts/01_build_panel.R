suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(tibble)
})

setup_file <- if (file.exists(file.path("scripts", "_ps1_setup.R"))) {
  file.path("scripts", "_ps1_setup.R")
} else {
  file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "_ps1_setup.R")
}
source(setup_file, local = TRUE)

data_file <- file.path(data_dir, "compustat_funda_ps1.csv")
require_file(data_file, "Run 00_download_wrds_server.R first.")

required_columns <- c(
  "gvkey", "datadate", "fyear", "sic", "fic", "tic", "conml", "at",
  "capx", "ppegt", "dltt", "dlc", "prcc_f", "csho", "ibc", "dpc"
)

raw <- fread(data_file, colClasses = c(gvkey = "character")) |>
  as_tibble()

missing_columns <- setdiff(required_columns, names(raw))
if (length(missing_columns) > 0L) {
  stop("The input file is missing: ", paste(missing_columns, collapse = ", "))
}

duplicate_firm_year <- raw |>
  count(gvkey, fyear, name = "observations") |>
  filter(observations > 1L)

if (nrow(duplicate_firm_year) > 0L) {
  write_csv(duplicate_firm_year, file.path(proc_dir, "input_duplicate_firm_years.csv"))
  stop("Duplicate gvkey-fyear rows found. See proc/input_duplicate_firm_years.csv.")
}

coverage <- target_firms |>
  select(gvkey, firm) |>
  left_join(
    raw |>
      filter(gvkey %in% target_firms$gvkey) |>
      group_by(gvkey) |>
      summarise(
        first_fyear = min(fyear),
        last_fyear = max(fyear),
        observations = n(),
        missing_years = paste(setdiff(expected_years, fyear), collapse = ", "),
        .groups = "drop"
      ),
    by = "gvkey"
  ) |>
  mutate(
    observations = replace_na(observations, 0L),
    complete_1980_2008 = observations == length(expected_years) &
      first_fyear == min(expected_years) & last_fyear == max(expected_years)
  )

write_csv(coverage, file.path(proc_dir, "input_coverage_check.csv"))

input_complete <- min(raw$fyear, na.rm = TRUE) == 1980L &&
  all(coverage$complete_1980_2008)

if (!input_complete) {
  warning(
    "The source CSV lacks complete 1980--2008 coverage. Continuing with ",
    "diagnostic outputs; see proc/input_coverage_check.csv."
  )
}

winsorize <- function(x, probabilities = c(0.01, 0.99)) {
  cutoffs <- quantile(x, probs = probabilities, na.rm = TRUE, names = FALSE, type = 7)
  pmin(pmax(x, cutoffs[[1L]]), cutoffs[[2L]])
}

full_panel <- raw |>
  filter(fyear %in% expected_years) |>
  arrange(gvkey, fyear, datadate) |>
  group_by(gvkey) |>
  mutate(
    previous_fyear = lag(fyear),
    lag_ppegt = if_else(fyear - previous_fyear == 1L, lag(ppegt), NA_real_),
    lag_at = if_else(fyear - previous_fyear == 1L, lag(at), NA_real_)
  ) |>
  ungroup() |>
  mutate(
    k = ppegt,
    inv_rate_raw = capx / lag_ppegt,
    q_raw = (dltt + dlc + prcc_f * csho - at) / ppegt,
    cash_flow_raw = (ibc + dpc) / lag_at,
    inv_rate = winsorize(inv_rate_raw),
    q = winsorize(q_raw),
    cash_flow = winsorize(cash_flow_raw)
  ) |>
  group_by(gvkey) |>
  mutate(q_lag = if_else(fyear - lag(fyear) == 1L, lag(q), NA_real_)) |>
  ungroup()

fwrite(as.data.table(full_panel), file.path(proc_dir, "01_full_analysis_panel.csv"), na = "")

balanced_panel <- full_panel |>
  group_by(gvkey) |>
  filter(
    n() == length(expected_years),
    n_distinct(fyear) == length(expected_years),
    all(expected_years %in% fyear),
    all(!is.na(ppegt))
  ) |>
  ungroup() |>
  group_by(fyear) |>
  mutate(computed_bin = ntile(ppegt, 3L)) |>
  ungroup()

stable_bin_panel <- balanced_panel |>
  group_by(gvkey) |>
  filter(n_distinct(computed_bin) == 1L) |>
  ungroup()

fwrite(
  as.data.table(balanced_panel),
  file.path(proc_dir, "02_balanced_panel_with_annual_bins.csv"),
  na = ""
)
fwrite(
  as.data.table(stable_bin_panel),
  file.path(proc_dir, "03_stable_bin_panel.csv"),
  na = ""
)

computed_target_bins <- stable_bin_panel |>
  filter(gvkey %in% target_firms$gvkey) |>
  distinct(gvkey, computed_bin)

three_firm_panel <- full_panel |>
  filter(gvkey %in% target_firms$gvkey) |>
  inner_join(target_firms, by = "gvkey", suffix = c("_wrds", "")) |>
  left_join(computed_target_bins, by = "gvkey") |>
  arrange(assigned_bin, fyear)

regression_sample <- three_firm_panel |>
  filter(if_all(c(inv_rate, q_lag, cash_flow), is.finite))

regression_coverage <- regression_sample |>
  count(gvkey, firm, name = "regression_observations")

write_csv(regression_coverage, file.path(proc_dir, "regression_coverage_check.csv"))

regression_complete <- nrow(regression_coverage) == 3L &&
  all(regression_coverage$regression_observations == 28L)

if (!regression_complete) {
  warning("The regression sample is incomplete; diagnostic outputs will use available years.")
}

fwrite(as.data.table(three_firm_panel), file.path(proc_dir, "04_three_firm_panel.csv"), na = "")
fwrite(as.data.table(regression_sample), file.path(proc_dir, "05_three_firm_regression_sample.csv"), na = "")

write_csv(
  tibble(
    input_complete = input_complete,
    regression_complete = regression_complete,
    earliest_source_year = min(raw$fyear, na.rm = TRUE),
    latest_source_year = max(raw$fyear, na.rm = TRUE)
  ),
  file.path(proc_dir, "panel_build_status.csv")
)

message("Panel construction complete. Intermediate datasets: ", proc_dir)
