# ==========================================================================
# Question 1
# SDTM DS Domain Creation
# Package: {sdtm.oak}
#
# PURPOSE:
# Transform raw disposition (DS) data into an SDTM-compliant DS domain.
# The implementation follows a variable-by-variable approach using {sdtm.oak},
# ensuring traceability between raw source data and SDTM outputs. The approach
# follows the AE example: https://pharmaverse.github.io/examples/sdtm/ae.html
# and implements rules from the mock-up eCRF PDF:
#   - DSTERM:
#       - If OTHERSP is NULL then DSTERM = IT.DSTERM
#       - If OTHERSP is not NULL then DSTERM = OTHERSP
#   - DSDECOD:
#       - If OTHERSP is NULL then DSDECOD = IT.DSDECOD
#       - If OTHERSP is not NULL then DSDECOD = OTHERSP
#   - DSCAT:
#       - If IT.DSDECOD = "RANDOMIZED" then DSCAT = "PROTOCOL MILESTONE"
#       - Else DSCAT = "DISPOSITION EVENT"
#       - If OTHERSP is not NULL then DSCAT = "OTHER EVENT"
#   - DSDTC:
#       - DSDTC = DSDTCOL + DSTMCOL in ISO8601 format (MM-DD-YYYY hh:mm)
#   - DSSTDTC:
#       - DSSTDTC = IT.DSSTDAT in ISO8601 format (MM-DD-YYYY)
#
# INPUT:
# - pharmaverseraw::ds_raw
# - Study-specific controlled terminology (study_ct.csv)
# - DM and SV SDTM reference domains (pharmaversesdtm::dm, pharmaversesdtm::sv)
#
# OUTPUT:
# - ds_final.csv
# - question_1_log.txt (script execution log)
# ==========================================================================


# ==========================================================================
# SDTM.OAK Functions Summary
# --------------------------------------------------------------------------
# Function                   | Purpose
# --------------------------------------------------------------------------
# generate_oak_id_vars()     | Create unique row IDs for traceability between raw and SDTM data
# assign_no_ct()             | Map raw variables to SDTM without controlled terminology
# assign_ct()                | Map raw variables to SDTM using controlled terminology (CT)
# assign_datetime()          | Convert raw date/time columns to ISO8601 format (supports single or combined date+time)
# derive_seq()               | Assign sequential record numbers per subject (DSSEQ)
# derive_study_day()         | Calculate study day (DSSTDY) relative to reference date (RFSTDTC) from DM
# ==========================================================================


# -----------------------------
# 1. Load required libraries
# -----------------------------
library(sdtm.oak)          # SDTM mapping and derivation functions
library(pharmaverseraw)    # Raw study datasets
library(pharmaversesdtm)   # SDTM reference domains (DM, SV)
library(dplyr)             # Data manipulation functions


# -----------------------------
# 2. Read raw DS dataset and SDTM reference domains
# -----------------------------
ds_raw <- pharmaverseraw::ds_raw     # Raw DS dataset
dm     <- pharmaversesdtm::dm        # DM domain (used for DSSTDY derivation)
sv     <- pharmaversesdtm::sv        # SV domain (used for VISITNUM mapping)


# -----------------------------
# 3. Generate unique row IDs and prepare raw variables
# -----------------------------
ds_raw <- ds_raw %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",  # Patient identifier used to generate unique row IDs
    raw_src = "ds_raw"   # Source dataset label
  ) %>%
  mutate(
    # DSTERM: Use OTHERSP if present, otherwise original IT.DSTERM
    IT.DSTERM  = coalesce(OTHERSP, IT.DSTERM),
    
    # DSDECOD: Uppercase for consistency; OTHERSP overrides IT.DSDECOD
    IT.DSDECOD = toupper(coalesce(OTHERSP, IT.DSDECOD))
  )


# -----------------------------
# 4. Read study-specific controlled terminology (CT)
# -----------------------------
study_ct <- read.csv("data/study_ct.csv", stringsAsFactors = FALSE)


# -----------------------------
# 5. Map Topic Variable
# -----------------------------
ds <- assign_no_ct(
  raw_dat = ds_raw,        # Raw dataset to map
  raw_var = "IT.DSTERM",   # Source variable to map (without CT)
  tgt_var = "DSTERM",      # Target SDTM variable
  id_vars = oak_id_vars()  # Maintains row-level traceability between raw and SDTM
)


# -----------------------------
# 6. Map Rest of the Variables
# -----------------------------
ds <- ds %>%
  assign_ct(
    raw_dat = ds_raw,       
    raw_var = "IT.DSDECOD", # Source variable to map (with CT)
    tgt_var = "DSDECOD",
    ct_spec = study_ct,     # Study-specific CT reference table
    ct_clst = "C66727",     # CT codelist for DSDECOD (Disposition Event)
    id_vars = oak_id_vars()
  ) %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),  # Combine date and time columns
    tgt_var = "DSDTC",
    raw_fmt = c("m-d-y", "H:M"),        # Input format of raw date/time
    id_vars = oak_id_vars()
  ) %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = c("m-d-y"),
    id_vars = oak_id_vars()
  )


# -----------------------------
# 7. Create SDTM derived variables
# -----------------------------
ds <- ds %>%
  mutate(
    # Populate Required SDTM Identifier Variables (SDTMIG)
    STUDYID = ds_raw$STUDY,                 # Study identifier (copied from raw STUDY variable)
    DOMAIN  = "DS",                         # SDTM domain code for Disposition     
    USUBJID = paste0("01-", ds_raw$PATNUM), # Unique Subject Identifier derived from PATNUM
    
    # Convert to uppercase for SDTM consistency and CT alignment
    DSTERM  = toupper(DSTERM),
    
    # Derive DSCAT following mock-up eCRF rules
    DSCAT = case_when(
      !is.na(ds_raw$OTHERSP)             ~ "OTHER EVENT",       
      ds_raw$IT.DSDECOD == "RANDOMIZED"  ~ "PROTOCOL MILESTONE", 
      TRUE                               ~ "DISPOSITION EVENT"
    ),
    
    # Uppercase to ensure consistent join with SV domain
    VISIT = toupper(ds_raw$INSTANCE)
  ) %>%
  
  left_join(
    # Map VISITNUM from SV domain while preserving traceability
    sv %>% select(USUBJID, VISIT, VISITNUM), # Only required columns
    by = c("USUBJID", "VISIT")               # Join by subject ID and visit name
  ) %>%
  
  derive_seq(
    # derive_seq() assigns unique sequence numbers per subject for DS records
    tgt_var = "DSSEQ",                            # SDTM sequence variable
    rec_vars = c("STUDYID", "USUBJID", "DSSTDTC") # Chronological record number per subject based on DSSTDTC
  ) %>%
  
  derive_study_day(
    # Derive study day (DSSTDY) relative to RFSTDTC from DM
    sdtm_in = .,            # Current dataset in pipeline
    dm_domain = dm,         # DM reference domain for RFSTDTC
    tgdt = "DSSTDTC",       # Target date variable for calculation
    refdt = "RFSTDTC",      # Reference start date from DM
    study_day_var = "DSSTDY" # Derived study day variable
  ) %>%
  
  select(
    # Final variable selection and ordering
    STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD,
    DSCAT, VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
  )


# -----------------------------
# 8. Save final DS dataset to CSV
# -----------------------------
write.csv(ds, "question_1_sdtm/ds_final.csv", row.names = FALSE)


# -----------------------------
# 9. Simple log file to indicate script ran successfully
# -----------------------------
log_file <- "question_1_sdtm/question_1_log.txt"
writeLines(
  c(
    paste0("01_create_ds_domain.R executed successfully: ", Sys.time()),
    "No errors detected."
  ),
  con = log_file
)