# FIN971A Problem Set 1: WRDS data download

The script `scripts/00_download_wrds_server.R` downloads the Compustat
Fundamentals Annual observations needed for Problem Set 1. It writes the raw
download to:

```text
data/compustat_funda_ps1.csv
```

The download contains the complete eligible Compustat universe for fiscal
years 1980--2008, rather than only the three assigned companies. The complete
universe is needed to reproduce the balanced-panel restriction and annual
PP&E terciles described in the problem-set appendix.

## Running on the WRDS R server

1. Open `scripts/00_download_wrds_server.R` on the WRDS server.
2. Fill in the two empty credential values near the top of the script.
3. Run:

```bash
Rscript scripts/00_download_wrds_server.R
```

The script creates the `data` directory automatically. Do not commit or share
the script after inserting a real password.

## Downloaded variables

| Variable | Compustat meaning | Use in PS1 |
|---|---|---|
| `gvkey` | Compustat firm identifier | Identifies firms and defines the panel |
| `datadate` | Fiscal-year accounting date | Orders and dates annual observations |
| `fyear` | Fiscal year | Time index; the assignment uses 1980--2008 |
| `indfmt` | Industry format | Filtered to `INDL` |
| `datafmt` | Data format | Filtered to `STD` |
| `popsrc` | Population source | Filtered to domestic population `D` |
| `consol` | Consolidation code | Filtered to consolidated statements `C` |
| `sic` | SIC code (from `comp.company`) | Excludes financial firms (6000--6999) and utilities (4900--4999) |
| `fic` | Foreign incorporation code (from `comp.company`) | Filtered to `USA` |
| `tic` | Ticker symbol (from `comp.funda`) | Labels figures and tables |
| `conml` | Company legal name (from `comp.company`) | Labels figures and tables |
| `at` | Total assets | Book assets and lagged denominator of cash flow |
| `capx` | Capital expenditures | Numerator of the investment rate |
| `ppegt` | Property, plant, and equipment, gross total | Capital stock, lagged investment denominator, Q denominator, and size-tercile variable |
| `dltt` | Long-term debt | Component of Tobin's Q |
| `dlc` | Debt in current liabilities | Short-term-debt component of Tobin's Q |
| `prcc_f` | Fiscal-year closing stock price | Component of market equity |
| `csho` | Common shares outstanding | Component of market equity |
| `ibc` | Income before extraordinary items, cash-flow statement | Component of cash flow |
| `dpc` | Depreciation and amortization, cash-flow statement | Component of cash flow |

## PS1 variable construction

Sort observations by `gvkey fyear`, restrict the analysis sample to
1980--2008, and construct:

```text
K_t            = ppegt_t
I_t / K_(t-1)  = capx_t / ppegt_(t-1)
Q_t            = (dltt_t + dlc_t + prcc_f_t * csho_t - at_t) / ppegt_t
Q_(t-1)        = one-year lag of Q_t within gvkey
CF_t           = (ibc_t + dpc_t) / at_(t-1)
```

The first sample year has no within-sample lag, leaving at most 28 regression
observations per firm. Apply the assignment's 1st/99th-percentile
winsorization rule to the constructed analysis variables.

The three assigned firms are:

| Size bin | Company | GVKEY |
|---|---|---|
| 1 (small) | EMS Technologies Inc. | `004279` |
| 2 (medium) | Atwood Oceanics Inc. | `001860` |
| 3 (large) | Raytheon Technologies Corp. | `010983` |

CRSP and the CRSP/Compustat link table are not required for the assignment's
stated definitions. Market equity in the appendix is based on Compustat
`prcc_f * csho`.

## Analysis

After downloading the corrected raw CSV, run the full workflow with:

```bash
Rscript scripts/01_analyze_ps1.R
```

`01_analyze_ps1.R` is a small master runner. The component scripts may instead
be run separately, in this order:

```bash
Rscript scripts/01_build_panel.R
Rscript scripts/02_make_plots.R
Rscript scripts/03_run_regressions.R
```

| Script | Purpose |
|---|---|
| `_ps1_setup.R` | Shared project paths, output directories, firm identifiers, and sample years |
| `01_build_panel.R` | Validates the WRDS CSV, constructs and winsorizes the PS1 variables, creates the balanced panel and size bins, and saves intermediate datasets to `proc/` |
| `02_make_plots.R` | Reads the processed three-firm panels and creates grid-free `ggplot2` Figures 1--4 |
| `03_run_regressions.R` | Produces Table 1 and estimates Tables 2--3 with `fixest::feols()` and heteroskedasticity-robust standard errors |

The workflow creates:

- Intermediate and analysis-ready CSV/RDS files in `proc/`.
- Figures 1--4 as 300-DPI PNG files in `results/figures/`.
- Summary statistics and regression tables in `results/tables/`. Regression
  tables are written as body-only LaTeX `tabular` fragments rather than Excel
  workbooks, so they can be inserted into a larger document or table float.
