# ==========================================================================
# SDTM DS Domain Creation
# Package: {sdtm.oak}
#
# PURPOSE:
# Transform raw disposition data into an SDTM-compliant DS domain.
# The implementation follows a variable-by-variable approach using
# {sdtm.oak} to ensure traceability between raw source data and SDTM outputs.
#
# INPUT:
# - pharmaverseraw::ds_raw
# - study-specific controlled terminology (study_ct.csv)
#
# OUTPUT:
# - ds_final.csv
#
# ASSUMPTIONS:
# - Visit numbering is study-specific and hardcoded due to limited metadata.
# - Some source dates contain inconsistent formats and may not fully parse.
# - Controlled terminology is limited to the provided codelist extract.
# ==========================================================================

# --------------------------------------------------------------------------
# Step 1: Load Required Packages
# --------------------------------------------------------------------------
library(pharmaverseraw)
library(dplyr)
library(stringr)
library(sdtm.oak)

# --------------------------------------------------------------------------
# Step 2: Prepare Output Location
# --------------------------------------------------------------------------
# Output directory is created to store the final dataset and log output.
# This keeps deliverables isolated per question.
if (!dir.exists("question_1_sdtm")) {
  dir.create("question_1_sdtm")
}

# --------------------------------------------------------------------------
# Step 3: Initialize Logging
# --------------------------------------------------------------------------
log_con <- file("question_1_sdtm/question_1_log.txt", open = "wt")
sink(log_con, type = "output")
sink(log_con, type = "message")

message("--------------------------------------------------")
message("SDTM DS DOMAIN CREATION STARTED: ", Sys.Date())
message("--------------------------------------------------")

# --------------------------------------------------------------------------
# Step 4: Load and Inspect Raw Data
# --------------------------------------------------------------------------
# Raw data is converted to a data.frame to avoid tibble-specific printing
# behavior during logging and joins.
raw_data <- pharmaverseraw::ds_raw %>%
  as.data.frame() %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

# Initial inspection to understand available variables and record count.
message("Raw DS record count: ", nrow(raw_data))
message("Raw DS variables:")
print(names(raw_data))

# --------------------------------------------------------------------------
# Step 5: Light Data Normalization (Observed Issues)
# --------------------------------------------------------------------------
# During early inspection and CT mapping attempts, mismatches were observed
# due to inconsistent casing and trailing spaces in disposition terms.
# Minimal normalization is applied here to support CT matching.
raw_data <- raw_data %>%
  mutate(
    IT.DSDECOD_CLN = toupper(trimws(IT.DSDECOD)),
    DSDTCOL        = str_replace_all(trimws(DSDTCOL), "/", "-"),
    DSTMCOL        = trimws(DSTMCOL),
    IT.DSSTDAT     = str_replace_all(trimws(IT.DSSTDAT), "/", "-")
  )

# --------------------------------------------------------------------------
# Step 6: Load Controlled Terminology
# --------------------------------------------------------------------------
# Study-specific CT is loaded from CSV and filtered to the DS codelist.
study_ct <- read.csv("data/study_ct.csv", stringsAsFactors = FALSE) %>%
  mutate(
    collected_value = toupper(trimws(collected_value))
  )

ds_ct <- study_ct %>%
  filter(codelist_code == "C66727")

message("Controlled terminology terms available for DS:")
print(unique(ds_ct$collected_value))

# --------------------------------------------------------------------------
# Step 7: Define Oak ID Variables
# --------------------------------------------------------------------------
# Oak ID variables uniquely identify each raw record and are required
# for traceable joins across derived variables.
id_vars <- oak_id_vars()

# --------------------------------------------------------------------------
# Step 8: Variable Derivations (Oak Objects)
# --------------------------------------------------------------------------

# DSTERM:
# Verbatim term carried forward from the source without CT mapping.
ds_term <- assign_no_ct(
  raw_dat = raw_data,
  tgt_var = "DSTERM",
  raw_var = "IT.DSTERM",
  id_vars = id_vars
)

# DSDECOD:
# Controlled terminology mapping is attempted for all records.
# Unmapped values are reviewed later and handled via fallback logic.
ds_decod <- assign_ct(
  raw_dat = raw_data,
  tgt_var = "DSDECOD",
  raw_var = "IT.DSDECOD_CLN",
  ct_spec = ds_ct,
  ct_clst = "C66727",
  id_vars = id_vars
)

# --------------------------------------------------------------------------
# Exploratory Check: CT Mapping Coverage
# --------------------------------------------------------------------------
# This check is included to understand how many disposition terms were
# successfully mapped to controlled terminology versus remaining unmapped.
message("CT mapping coverage check:")
raw_data %>%
  count(IT.DSDECOD_CLN %in% ds_ct$collected_value) %>%
  print()

# --------------------------------------------------------------------------
# DSDTC:
# Date/time of disposition event derived using date and time components.
# Parsing warnings are not suppressed to allow review of problematic records.
ds_dtc <- assign_datetime(
  raw_dat = raw_data,
  tgt_var = "DSDTC",
  raw_var = c("DSDTCOL", "DSTMCOL"),
  raw_fmt = c("d-m-y", "H:M"),
  id_vars = id_vars
)

# DSSTDTC:
# Start date of the disposition event.
ds_stdtc <- assign_datetime(
  raw_dat = raw_data,
  tgt_var = "DSSTDTC",
  raw_var = "IT.DSSTDAT",
  raw_fmt = "d-m-y",
  id_vars = id_vars
)

# --------------------------------------------------------------------------
# Step 9: Assemble DS Domain and Apply Business Rules
# --------------------------------------------------------------------------
ds_final <- raw_data %>%
  left_join(ds_term,  by = id_vars) %>%
  left_join(ds_decod, by = id_vars) %>%
  left_join(ds_dtc,   by = id_vars) %>%
  left_join(ds_stdtc, by = id_vars) %>%
  mutate(
    # If CT mapping is missing, retain normalized source value.
    DSDECOD = coalesce(DSDECOD, IT.DSDECOD_CLN),
    
    # "Other, Specify" overrides both coded and verbatim terms.
    DSTERM  = if_else(!is.na(OTHERSP) & OTHERSP != "", OTHERSP, DSTERM),
    DSDECOD = if_else(!is.na(OTHERSP) & OTHERSP != "", OTHERSP, DSDECOD),
    
    # Categorization distinguishes protocol milestones from disposition events.
    DSCAT = case_when(
      !is.na(OTHERSP) & OTHERSP != "" ~ "OTHER EVENT",
      IT.DSDECOD_CLN == "RANDOMIZED"  ~ "PROTOCOL MILESTONE",
      TRUE                            ~ "DISPOSITION EVENT"
    ),
    
    STUDYID = STUDY,
    DOMAIN  = "DS",
    USUBJID = paste0(STUDY, "-", PATNUM),
    VISIT   = INSTANCE,
    
    # Visit numbering derived based on observed INSTANCE values.
    # In a production study, this would typically be sourced from SV
    # or visit-level metadata; hardcoded here due to assessment scope.
    VISITNUM = case_when(
      str_detect(toupper(VISIT), "BASELINE") ~ 10,
      str_detect(toupper(VISIT), "WEEK 4")   ~ 40,
      str_detect(toupper(VISIT), "WEEK 26")  ~ 260,
      TRUE                                   ~ NA_real_
    ),
    
    # Study day not derived due to missing reference start day logic.
    DSSTDY = NA_integer_
  ) %>%
  # Filter out empty records as per SDTM IG
  filter(!is.na(DSTERM) & DSTERM != "")

# Add sequence numbers
ds_final <- ds_final %>%
  derive_seq(
    tgt_var = "DSSEQ",
    rec_vars = "USUBJID"
  ) %>%
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ,
    DSTERM, DSDECOD, DSCAT,
    VISITNUM, VISIT,
    DSDTC, DSSTDTC, DSSTDY
  )

# --------------------------------------------------------------------------
# Step 10: Output and Review
# --------------------------------------------------------------------------
write.csv(ds_final, "question_1_sdtm/ds_final.csv", row.names = FALSE)

# Ensure the preview prints even when sink() is active
message("Preview of final DS dataset:")
if (nrow(ds_final) > 0) {
  # Force printing to console/log
  print(as.data.frame(head(ds_final, 10)))
} else {
  message("Warning: ds_final has zero rows after filtering.")
}

message("--------------------------------------------------")
message("SDTM DS DOMAIN CREATION COMPLETED")
message("--------------------------------------------------")

sink(type = "message")
sink(type = "output")
close(log_con)