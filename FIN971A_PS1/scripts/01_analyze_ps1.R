# Master runner for FIN971A Problem Set 1.
# Each stage can also be run independently in the order listed below.

command_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", command_args, value = TRUE)

if (length(file_arg) == 1L) {
  scripts_dir <- dirname(normalizePath(
    sub("^--file=", "", file_arg),
    winslash = "/",
    mustWork = TRUE
  ))
} else if (dir.exists(file.path(getwd(), "scripts"))) {
  scripts_dir <- normalizePath(file.path(getwd(), "scripts"), winslash = "/")
} else {
  scripts_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

stages <- c(
  "01_build_panel.R",
  "02_make_plots.R",
  "03_run_regressions.R"
)

for (stage in stages) {
  message("\nRunning ", stage, "...")
  source(file.path(scripts_dir, stage), local = new.env(parent = globalenv()))
}

message("\nAll FIN971A PS1 analysis stages finished.")
