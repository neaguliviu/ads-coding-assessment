# ==========================================================================
# AE Summary Table Creation using {gtsummary}
#
# PURPOSE:
# Create a summary table of Treatment-Emergent Adverse Events (TEAEs)
# by treatment group for the Safety Population.
#
# The table structure is aligned with the intent of FDA Table 10:
# - Subjects counted once per Preferred Term
# - Hierarchical display using System Organ Class (SOC) and Preferred Term (PT)
# - Counts (n) and percentages (%) by treatment arm
#
# INPUT:
# - pharmaverseadam::adae
# - pharmaverseadam::adsl (used for denominator context)
#
# OUTPUT:
# - ae_summary_table.html
#
# ASSUMPTIONS:
# - Safety Population is defined by SAFFL == "Y"
# - Treatment-Emergent AEs are identified using TRTEMFL == "Y"
# - ACTARM represents the analysis treatment group
# - No custom AE severity pooling is required for this assessment
# ==========================================================================

# --------------------------------------------------------------------------
# Step 1: Load Required Packages
# --------------------------------------------------------------------------
library(dplyr)
library(gtsummary)
library(gt)
library(forcats)
library(pharmaverseadam)

# --------------------------------------------------------------------------
# Step 2: Prepare Output Location
# --------------------------------------------------------------------------
# Output directory is created to keep Question 3 deliverables isolated.
if (!dir.exists("question_3_tlg")) {
  dir.create("question_3_tlg")
}

# --------------------------------------------------------------------------
# Step 3: Load Source ADaM Datasets
# --------------------------------------------------------------------------
# ADAE contains adverse event records at the subject-event level.
# ADSL is used implicitly for population context (e.g. total subjects).
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

message("ADAE record count: ", nrow(adae))
message("ADSL record count: ", nrow(adsl))

# --------------------------------------------------------------------------
# Step 4: Filter for Safety Population and TEAEs
# --------------------------------------------------------------------------
# Only treatment-emergent adverse events in the safety population
# are included, as required by the assignment.
ae_subset <- adae %>%
  filter(
    SAFFL == "Y",
    TRTEMFL == "Y"
  ) %>%
  select(
    USUBJID,
    ACTARM,
    AESOC,
    AETERM
  )

message("TEAE records in safety population: ", nrow(ae_subset))

# --------------------------------------------------------------------------
# Step 5: Light Data Preparation for Display
# --------------------------------------------------------------------------
# SOC and PT values are normalized to ensure consistent grouping
# and to avoid duplicate factor levels caused by casing differences.
# Factors are ordered by frequency to support descending sort.
ae_subset <- ae_subset %>%
  mutate(
    AESOC  = toupper(AESOC),
    AETERM = toupper(AETERM),
    AESOC  = fct_infreq(AESOC),
    AETERM = fct_infreq(AETERM)
  )

# --------------------------------------------------------------------------
# Step 6: Create AE Summary Table (FDA Table 10 Style)
# --------------------------------------------------------------------------
# This implementation follows the FDA Table 10 pattern using
# tbl_hierarchical(), which:
# - Counts subjects once per PT
# - Nests PTs under SOCs
# - Calculates n (%) per treatment group
#
# A total column is included using overall_row = TRUE.
ae_table <- ae_subset %>%
  tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,
    id = USUBJID,
    denominator = adsl,
    statistic = all_categorical() ~ "{n} ({p}%)",
    overall_row = TRUE,
    label = list(
      "..ard_hierarchical_overall.." ~ "Treatment-Emergent Adverse Events"
    )
  ) %>%
  modify_header(
    label = "**Primary System Organ Class <br> Reported Term for the Adverse Event**"
  ) %>%
  bold_labels()

# --------------------------------------------------------------------------
# Step 7: Output Table
# --------------------------------------------------------------------------
# Table is saved as HTML to preserve formatting and hierarchy.
ae_table %>%
  as_gt() %>%
  gt::gtsave("question_3_tlg/ae_summary_table.html")

message("--------------------------------------------------")
message("AE SUMMARY TABLE CREATED SUCCESSFULLY")
message("Output: question_3_tlg/ae_summary_table.html")
message("--------------------------------------------------")