suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(fixest)
  library(readr)
  library(tibble)
})

setup_file <- if (file.exists(file.path("scripts", "_ps1_setup.R"))) {
  file.path("scripts", "_ps1_setup.R")
} else {
  file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "_ps1_setup.R")
}
source(setup_file, local = TRUE)

regression_file <- file.path(proc_dir, "05_three_firm_regression_sample.csv")
three_firm_file <- file.path(proc_dir, "04_three_firm_panel.csv")
require_file(regression_file, "Run 01_build_panel.R first.")
require_file(three_firm_file, "Run 01_build_panel.R first.")

regression_sample <- fread(regression_file, colClasses = c(gvkey = "character")) |>
  as_tibble()
three_firm_panel <- fread(three_firm_file, colClasses = c(gvkey = "character")) |>
  as_tibble()

# Table 1 uses each variable's available observations. Thus K has 29 annual
# observations, while the lag-dependent I/K, CF, and Q series have 28.
summary_statistics <- three_firm_panel |>
  group_by(assigned_bin, gvkey, firm) |>
  summarise(
    k_mean = mean(k, na.rm = TRUE),
    k_sd = sd(k, na.rm = TRUE),
    inv_rate_mean = mean(inv_rate, na.rm = TRUE),
    inv_rate_sd = sd(inv_rate, na.rm = TRUE),
    cash_flow_mean = mean(cash_flow, na.rm = TRUE),
    cash_flow_sd = sd(cash_flow, na.rm = TRUE),
    q_mean = mean(q_lag, na.rm = TRUE),
    q_sd = sd(q_lag, na.rm = TRUE),
    observations = n(),
    .groups = "drop"
  ) |>
  arrange(assigned_bin)

write_csv(summary_statistics, file.path(tables_dir, "table1_summary_statistics.csv"))

summary_long <- summary_statistics |>
  select(assigned_bin, firm, starts_with("k_"), starts_with("inv_rate_"),
         starts_with("cash_flow_"), starts_with("q_")) |>
  pivot_longer(
    cols = -c(assigned_bin, firm),
    names_to = c("variable", ".value"),
    names_pattern = "(k|inv_rate|cash_flow|q)_(mean|sd)"
  ) |>
  mutate(
    variable = factor(
      variable,
      levels = c("k", "inv_rate", "cash_flow", "q"),
      labels = c("$K$", "$I/K$", "$CF$", "$Q$")
    )
  ) |>
  arrange(assigned_bin, variable)

summary_tex_rows <- summary_long |>
  group_by(assigned_bin, firm) |>
  summarise(
    rows = paste0(
      c(
        paste0("\\multicolumn{3}{l}{\\textit{", first(firm), "}} \\\\"),
        sprintf("%s & %.2f & (%.2f) \\\\", variable, mean, sd)
      ),
      collapse = "\n"
    ),
    .groups = "drop"
  ) |>
  pull(rows)

writeLines(
  c(
    "\\begin{tabular}{lrr}",
    "\\toprule",
    "Variable & Mean & Std. Dev. \\\\",
    "\\midrule",
    summary_tex_rows,
    "\\bottomrule",
    "\\end{tabular}"
  ),
  file.path(tables_dir, "table1_summary_statistics.tex")
)

split_samples <- regression_sample |>
  arrange(assigned_bin) |>
  group_split(assigned_bin)

models_no_cf <- split_samples |>
  lapply(function(firm_data) {
    feols(inv_rate ~ q_lag, data = firm_data, vcov = "hetero")
  })

models_with_cf <- split_samples |>
  lapply(function(firm_data) {
    feols(inv_rate ~ q_lag + cash_flow, data = firm_data, vcov = "hetero")
  })

variable_dictionary <- c(
  inv_rate = "$I_t/K_{t-1}$",
  q_lag = "$Q_{t-1}$",
  cash_flow = "$CF_t$"
)

tabular_only <- function(tex_lines) {
  start <- grep("^\\\\begin\\{tabular\\}", tex_lines)
  end <- grep("^\\\\end\\{tabular\\}", tex_lines)

  if (length(start) != 1L || length(end) != 1L || start > end) {
    stop("Could not isolate the tabular environment from the fixest output.")
  }

  tex_lines[start:end]
}

table2_tex <- etable(
  models_no_cf,
  tex = TRUE,
  float = FALSE,
  headers = list(" " = target_firms$firm),
  dict = variable_dictionary,
  drop = "Constant",
  coefstat = "se",
  se.below = TRUE,
  digits = "r3",
  digits.stats = "r3",
  fitstat = c("n", "r2"),
  style.tex = style.tex(tablefoot = FALSE)
)
writeLines(
  tabular_only(table2_tex),
  file.path(tables_dir, "table2_regression_no_cash_flow.tex")
)

table3_tex <- etable(
  models_with_cf,
  tex = TRUE,
  float = FALSE,
  headers = list(" " = target_firms$firm),
  dict = variable_dictionary,
  drop = "Constant",
  coefstat = "se",
  se.below = TRUE,
  digits = "r3",
  digits.stats = "r3",
  fitstat = c("n", "r2"),
  style.tex = style.tex(tablefoot = FALSE)
)
writeLines(
  tabular_only(table3_tex),
  file.path(tables_dir, "table3_regression_with_cash_flow.tex")
)

saveRDS(models_no_cf, file.path(proc_dir, "models_no_cash_flow.rds"))
saveRDS(models_with_cf, file.path(proc_dir, "models_with_cash_flow.rds"))

message("Summary and regression tables written to: ", tables_dir)
