# Shared paths and constants for the FIN971A PS1 scripts.
command_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", command_args, value = TRUE)

if (length(file_arg) == 1L) {
  scripts_dir <- dirname(normalizePath(
    sub("^--file=", "", file_arg),
    winslash = "/",
    mustWork = TRUE
  ))
} else if (file.exists(file.path(getwd(), "scripts", "_ps1_setup.R"))) {
  scripts_dir <- normalizePath(file.path(getwd(), "scripts"), winslash = "/")
} else {
  scripts_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

project_dir <- dirname(scripts_dir)
data_dir <- file.path(project_dir, "data")
proc_dir <- file.path(project_dir, "proc")
figures_dir <- file.path(project_dir, "results", "figures")
tables_dir <- file.path(project_dir, "results", "tables")

dir.create(proc_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

target_firms <- tibble::tribble(
  ~gvkey,   ~firm,                         ~short_name,        ~ticker, ~assigned_bin,
  "004279", "EMS Technologies Inc.",       "EMS Technologies", "ELMG",  1L,
  "001860", "Atwood Oceanics Inc.",        "Atwood Oceanics",  "ATW",   2L,
  "010983", "Raytheon Technologies Corp.", "Raytheon",         "RTX",   3L
)

expected_years <- 1980:2008

require_file <- function(path, instruction = NULL) {
  if (!file.exists(path)) {
    suffix <- if (is.null(instruction)) "" else paste0(" ", instruction)
    stop("Missing required file: ", path, ".", suffix)
  }
}
