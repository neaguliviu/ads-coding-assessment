# ==========================================================================
# Question 4: Export ADAE Dataset 
# Package: {pharmaverseadam}
#
# PURPOSE:
# Export the ADAE dataset from the Pharmaverse ADaM package
# to CSV format for use in Question 4.
#
# OUTPUT:
# - question_4_genai/data/adae.csv
# ==========================================================================

# Step 1: Prepare output directory
output_dir <- "question_4_genai/data"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Step 2: Load required package
library(pharmaverseadam)

# Step 3: Export ADAE
write.csv(adae, file = file.path(output_dir, "adae.csv"), row.names = FALSE)

message("ADAE dataset exported successfully to: ", output_dir)