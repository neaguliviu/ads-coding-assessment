# ==========================================================================
# ADaM ADSL Dataset Creation
# Package: {admiral}
#
# PURPOSE:
# Create a subject-level ADaM dataset (ADSL) from SDTM inputs.
# The dataset includes demographic variables, treatment timing,
# population flags, and last-known-alive date.
#
# INPUT:
# - pharmaversesdtm::dm
# - pharmaversesdtm::ex
# - pharmaversesdtm::ae
# - pharmaversesdtm::vs
# - pharmaversesdtm::ds
#
# OUTPUT:
# - adsl_final.csv
#
# ASSUMPTIONS:
# - ITT population is defined as subjects with a non-missing ARM.
# - Treatment start is based on first non-zero dose or placebo record.
# - Last-known-alive date may appear in multiple SDTM domains.
# - Partial date imputation rules are limited by available metadata.
# ==========================================================================

# --------------------------------------------------------------------------
# Step 1: Load Required Packages
# --------------------------------------------------------------------------
library(pharmaversesdtm)
library(admiral)
library(dplyr)
library(stringr)
library(lubridate)

# --------------------------------------------------------------------------
# Step 2: Prepare Output Location
# --------------------------------------------------------------------------
if (!dir.exists("question_2_adam")) {
  dir.create("question_2_adam")
}

# --------------------------------------------------------------------------
# Step 3: Initialize Logging
# --------------------------------------------------------------------------
log_con <- file("question_2_adam/question_2_log.txt", open = "wt")
sink(log_con, type = "output")
sink(log_con, type = "message")

message("--------------------------------------------------")
message("ADSL DERIVATION STARTED: ", Sys.Date())
message("--------------------------------------------------")

# --------------------------------------------------------------------------
# Step 4: Load Source SDTM Datasets
# --------------------------------------------------------------------------
dm <- pharmaversesdtm::dm
ex <- pharmaversesdtm::ex
ae <- pharmaversesdtm::ae
vs <- pharmaversesdtm::vs
ds <- pharmaversesdtm::ds

message("Record counts:")
message("DM: ", nrow(dm))
message("EX: ", nrow(ex))
message("AE: ", nrow(ae))
message("VS: ", nrow(vs))
message("DS: ", nrow(ds))

# --------------------------------------------------------------------------
# Step 5: Create ADSL Foundation from DM
# --------------------------------------------------------------------------
# ADSL is built starting from DM, as it contains one record per subject.
# Only variables relevant to subject-level analysis are retained.
adsl <- dm %>%
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    ARM, ARMCD,
    RFSTDTC,
    AGE, SEX, RACE
  )

# --------------------------------------------------------------------------
# Step 6: Derive Age Groupings
# --------------------------------------------------------------------------
# Age groupings are commonly required for subgroup analyses.
# Boundaries are defined based on assessment requirements.
adsl <- adsl %>%
  mutate(
    AGEGR9 = case_when(
      AGE < 18              ~ "<18",
      AGE >= 18 & AGE <= 50 ~ "18 - 50",
      AGE > 50              ~ ">50",
      TRUE                  ~ NA_character_
    ),
    AGEGR9N = case_when(
      AGEGR9 == "<18"     ~ 1,
      AGEGR9 == "18 - 50" ~ 2,
      AGEGR9 == ">50"     ~ 3,
      TRUE                ~ NA_real_
    )
  )

# --------------------------------------------------------------------------
# Step 7: Derive ITT Population Flag
# --------------------------------------------------------------------------
# ITT population is defined here as all subjects assigned to a treatment arm.
# This definition is documented due to limited study-level metadata.
adsl <- adsl %>%
  mutate(
    ITTFL = if_else(!is.na(ARM) & ARM != "", "Y", "N")
  )

# --------------------------------------------------------------------------
# Step 8: Prepare EX Data for Treatment Start Derivation
# --------------------------------------------------------------------------
# Treatment start is derived from EX records with non-zero dose.
# Placebo records with zero dose are retained where applicable.
ex_ext <- ex %>%
  filter(
    EXDOSE > 0 |
      (EXDOSE == 0 & str_detect(toupper(EXTRT), "PLACEBO"))
  )

message("EX records used for treatment start: ", nrow(ex_ext))

# --------------------------------------------------------------------------
# Step 9: Derive Treatment Start Date/Time
# --------------------------------------------------------------------------
# Treatment start date/time is derived as the first qualifying EX record.
# Partial date handling is limited due to lack of imputation metadata.
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = !is.na(EXSTDTC),
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(
      TRTSDTM = convert_dtc_to_dtm(EXSTDTC, highest_imputation = "h"),
      # Logic: If date length is 10 (YYYY-MM-DD), time was missing, so flag 'H'
      TRTSTMF = if_else(!is.na(EXSTDTC) & nchar(EXSTDTC) <= 10, "H", NA_character_)
    ),
    order = exprs(TRTSDTM),
    mode = "first"
  )

# --------------------------------------------------------------------------
# Step 10: Derive Last Known Alive Date (LSTAVLDT)
# --------------------------------------------------------------------------
# Last-known-alive date may be present across several SDTM domains.
# Initial derivation considered VS and AE only; DS and EX were added
# after reviewing where subject activity dates may be recorded.
events_list <- list(
  event(
    dataset_name = "vs",
    condition = !is.na(VSDTC),
    order = exprs(convert_dtc_to_dt(VSDTC)),
    set_values_to = exprs(LSTAVLDT = convert_dtc_to_dt(VSDTC))
  ),
  event(
    dataset_name = "ae",
    condition = !is.na(AESTDTC),
    order = exprs(convert_dtc_to_dt(AESTDTC)),
    set_values_to = exprs(LSTAVLDT = convert_dtc_to_dt(AESTDTC))
  ),
  event(
    dataset_name = "ds",
    condition = !is.na(DSSTDTC),
    order = exprs(convert_dtc_to_dt(DSSTDTC)),
    set_values_to = exprs(LSTAVLDT = convert_dtc_to_dt(DSSTDTC))
  ),
  event(
    dataset_name = "ex_ext",
    condition = !is.na(EXSTDTC),
    order = exprs(convert_dtc_to_dt(EXSTDTC)),
    set_values_to = exprs(LSTAVLDT = convert_dtc_to_dt(EXSTDTC))
  )
)

adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = events_list,
    source_datasets = list(
      vs = vs,
      ae = ae,
      ds = ds,
      ex_ext = ex_ext
    ),
    order = exprs(LSTAVLDT),
    mode = "last",
    new_vars = exprs(LSTAVLDT = LSTAVLDT)
  )

# --------------------------------------------------------------------------
# Step 11: Final Variable Selection
# --------------------------------------------------------------------------
adsl_final <- adsl %>%
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    AGE, AGEGR9, AGEGR9N,
    SEX, RACE,
    ARM, ARMCD,
    TRTSDTM, TRTSTMF,
    ITTFL,
    LSTAVLDT
  )

# --------------------------------------------------------------------------
# Step 12: Output and Review
# --------------------------------------------------------------------------
write.csv(adsl_final, "question_2_adam/adsl_final.csv", row.names = FALSE)

message("Preview of final ADSL dataset:")
print(head(adsl_final, 10))

message("--------------------------------------------------")
message("ADSL DERIVATION COMPLETED")
message("--------------------------------------------------")

sink(type = "message")
sink(type = "output")
close(log_con)