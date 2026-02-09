# ==========================================================================
# Question 3 Driver Script
#
# PURPOSE:
# Execute AE summary table and visualization scripts with logging.
# ==========================================================================

if (!dir.exists("question_3_tlg")) {
  dir.create("question_3_tlg")
}

log_con <- file("question_3_tlg/question_3_log.txt", open = "wt")
sink(log_con, type = "output")
sink(log_con, type = "message")

message("==================================================")
message("QUESTION 3 EXECUTION STARTED: ", Sys.Date())
message("==================================================")

message("--- Running AE Summary Table Script ---")
source("question_3_tlg/01_create_ae_summary_table.R")

message("--- Running AE Visualization Script ---")
source("question_3_tlg/02_create_ae_visualizations.R")

adae <- pharmaverseadam::adae %>%
  filter(SAFFL == "Y", TRTEMFL == "Y")

message("Final TEAE checks:")
message("Total records: ", nrow(adae))
message("Unique subjects: ", length(unique(adae$USUBJID)))

message("==================================================")
message("QUESTION 3 COMPLETED SUCCESSFULLY")
message("==================================================")

sink(type = "message")
sink(type = "output")
close(log_con)