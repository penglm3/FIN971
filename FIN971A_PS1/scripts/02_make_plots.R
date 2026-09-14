suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(tibble)
})

setup_file <- if (file.exists(file.path("scripts", "_ps1_setup.R"))) {
  file.path("scripts", "_ps1_setup.R")
} else {
  file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "_ps1_setup.R")
}
source(setup_file, local = TRUE)

three_firm_file <- file.path(proc_dir, "04_three_firm_panel.csv")
regression_file <- file.path(proc_dir, "05_three_firm_regression_sample.csv")
require_file(three_firm_file, "Run 01_build_panel.R first.")
require_file(regression_file, "Run 01_build_panel.R first.")

three_firm_panel <- fread(three_firm_file, colClasses = c(gvkey = "character")) |>
  as_tibble()
regression_sample <- fread(regression_file, colClasses = c(gvkey = "character")) |>
  as_tibble()

theme_ps1 <- function() {
  theme_classic(base_size = 12) +
    theme(
      panel.grid = element_blank(),
      strip.background = element_blank(),
      strip.text = element_text(face = "bold", size = 12),
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.title.y = element_blank(),
      legend.position = "bottom"
    )
}

plot_panel <- regression_sample |>
  select(gvkey, firm, short_name, assigned_bin, fyear, inv_rate, q_lag, cash_flow) |>
  pivot_longer(
    cols = c(inv_rate, q_lag, cash_flow),
    names_to = "measure",
    values_to = "value"
  ) |>
  mutate(
    measure = factor(
      measure,
      levels = c("inv_rate", "q_lag", "cash_flow"),
      labels = c("I/K", "Q", "CF")
    )
  )

for (i in seq_len(nrow(target_firms))) {
  firm_info <- target_firms[i, ]

  figure <- plot_panel |>
    filter(gvkey == firm_info$gvkey) |>
    ggplot(aes(x = fyear, y = value)) +
    geom_line(linewidth = 0.65, color = "black") +
    facet_wrap(~measure, scales = "free_y", nrow = 1) +
    scale_x_continuous(breaks = c(1980, 1990, 2000, 2010)) +
    labs(title = firm_info$firm, x = "Time") +
    theme_ps1()

  ggsave(
    filename = file.path(
      figures_dir,
      sprintf("figure%d_%s.png", firm_info$assigned_bin, gsub(" ", "_", tolower(firm_info$short_name)))
    ),
    plot = figure,
    width = 11,
    height = 3.8,
    dpi = 300,
    bg = "white"
  )
}

capital_plot_data <- three_firm_panel |>
  mutate(
    legend_label = sprintf("%s (Bin %d)", ticker, assigned_bin),
    legend_label = factor(
      legend_label,
      levels = sprintf("%s (Bin %d)", target_firms$ticker, target_firms$assigned_bin)
    )
  )

figure4 <- capital_plot_data |>
  ggplot(aes(x = fyear, y = k, color = legend_label, linetype = legend_label)) +
  geom_line(linewidth = 0.8) +
  scale_x_continuous(breaks = seq(1980, 2010, 5)) +
  labs(title = "Capital Stock", x = "Time", y = "K", color = NULL, linetype = NULL) +
  theme_ps1() +
  theme(
    axis.title.y = element_text(),
    legend.position = "inside",
    legend.position.inside = c(0.18, 0.80)
  )

ggsave(
  filename = file.path(figures_dir, "figure4_capital_stock.png"),
  plot = figure4,
  width = 8,
  height = 5.5,
  dpi = 300,
  bg = "white"
)

message("Figures 1--4 written to: ", figures_dir)
