suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(data.table)
})

root <- "/home/wisc/penglm3/FIN971/Dean-PS/PS1"
data_dir <- file.path(root, "data")

# Fill these in only on the WRDS server before running this script.
Sys.setenv(WRDS_USER = "")
Sys.setenv(WRDS_PASSWORD = "")

dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
output_file <- file.path(data_dir, "compustat_funda_ps1.csv")

user <- Sys.getenv("WRDS_USER")
password <- Sys.getenv("WRDS_PASSWORD")

if (!nzchar(user) || !nzchar(password)) {
  stop("Fill in WRDS_USER and WRDS_PASSWORD at the top of this script.")
}

download_ps1_data <- function() {
con <- dbConnect(
  RPostgres::Postgres(),
  host = "wrds-pgdata.wharton.upenn.edu",
  port = 9737,
  dbname = "wrds",
  sslmode = "require",
  user = user,
  password = password
)
on.exit(dbDisconnect(con), add = TRUE)

# Download the full filtered Compustat universe. Keeping all eligible firms is
# necessary to reproduce the annual PP&E terciles and balanced-panel screen.
# The window begins in 1980 because the supplied regressions have 28 usable
# observations: constructing lags within the 1980--2008 sample drops 1980.
funda_sql <- "
  select
    f.gvkey,
    f.datadate,
    f.fyear,
    f.indfmt,
    f.datafmt,
    f.popsrc,
    f.consol,
    case
      when trim(c.sic) ~ '^[0-9]+$' then cast(trim(c.sic) as integer)
    end as sic,
    c.fic,
    f.tic,
    c.conml,
    f.at,
    f.capx,
    f.ppegt,
    f.dltt,
    f.dlc,
    f.prcc_f,
    f.csho,
    f.ibc,
    f.dpc
  from comp.funda as f
  inner join comp.company as c
    on f.gvkey = c.gvkey
  where f.indfmt = 'INDL'
    and f.datafmt = 'STD'
    and f.popsrc = 'D'
    and f.consol = 'C'
    and f.fyear between 1980 and 2008
    and f.at > 0
    and (
      case when trim(c.sic) ~ '^[0-9]+$' then cast(trim(c.sic) as integer) end < 6000
      or case when trim(c.sic) ~ '^[0-9]+$' then cast(trim(c.sic) as integer) end > 6999
    )
    and (
      case when trim(c.sic) ~ '^[0-9]+$' then cast(trim(c.sic) as integer) end < 4900
      or case when trim(c.sic) ~ '^[0-9]+$' then cast(trim(c.sic) as integer) end > 4999
    )
    and f.gvkey is not null
    and trim(f.gvkey) <> ''
    and f.fyear is not null
    and c.fic = 'USA'
    and f.prcc_f is not null
    and f.csho is not null
  order by f.gvkey, f.fyear, f.datadate
"

message("Downloading Compustat Fundamentals Annual data from WRDS...")
funda <- as.data.table(dbGetQuery(con, funda_sql))

if (nrow(funda) == 0L) {
  stop("The WRDS query returned no observations; no file was written.")
}

# Guard against an unexpected duplicate firm-year before saving the raw data.
duplicate_firm_years <- funda[, .N, by = .(gvkey, fyear)][N > 1L]
if (nrow(duplicate_firm_years) > 0L) {
  warning(
    "The download contains ", nrow(duplicate_firm_years),
    " duplicated gvkey-fyear combinations. Inspect these before analysis."
  )
}

fwrite(funda, output_file, na = "")

target_gvkeys <- c("004279", "001860", "010983")
target_coverage <- funda[
  gvkey %in% target_gvkeys,
  .(first_fyear = min(fyear), last_fyear = max(fyear), observations = .N),
  by = gvkey
]

message("Wrote ", format(nrow(funda), big.mark = ","), " rows to: ", output_file)
message("Coverage for the three assigned firms:")
print(target_coverage)
}

download_ps1_data()
