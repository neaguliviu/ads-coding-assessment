# ==========================================================================
# AE Visualization Creation
#
# PURPOSE:
# Generate visual summaries for treatment-emergent adverse events:
# 1) AE severity distribution by treatment arm
# 2) Top 10 most frequent AEs with 95% confidence intervals
#
# INPUT:
# - pharmaverseadam::adae
#
# OUTPUT:
# - ae_severity_by_treatment.png
# - ae_top10_with_ci.png
# ==========================================================================

library(pharmaverseadam)
library(ggplot2)
library(dplyr)
library(binom)

adae <- pharmaverseadam::adae

ae_subset <- adae %>%
  filter(SAFFL == "Y", TRTEMFL == "Y") %>%
  select(USUBJID, ACTARM, AESEV, AETERM)

# --------------------------------------------------------------------------
# Plot 1: AE Severity Distribution
# --------------------------------------------------------------------------
severity_data <- ae_subset %>%
  count(ACTARM, AESEV)

ggplot(severity_data, aes(x = ACTARM, y = n, fill = AESEV)) +
  geom_bar(stat = "identity") +
  labs(
    title = "AE severity distribution by treatment",
    x = "Treatment Arm",
    y = "Count of AEs",
    fill = "Severity"
  ) +
  theme_minimal()

ggsave(
  "question_3_tlg/ae_severity_by_treatment.png",
  width = 8,
  height = 6
)

# --------------------------------------------------------------------------
# Plot 2: Top 10 Most Frequent AEs with 95% CI (as % of patients)
# --------------------------------------------------------------------------
top10_terms <- ae_subset %>%
  count(AETERM, sort = TRUE) %>%
  slice_head(n = 10)

# Quick validation before plotting
print(top10_terms)

# Use total safety population for denominator
TotalSubjects <- adae %>%
  filter(SAFFL == "Y") %>%
  summarise(n = n_distinct(USUBJID)) %>%
  pull(n)

top10_data <- top10_terms %>%
  mutate(
    TotalSubjects = TotalSubjects,        # Use full safety population
    Incidence = n / TotalSubjects
  )

ci <- binom.confint(
  top10_data$n,
  top10_data$TotalSubjects,
  methods = "exact"
)

top10_data <- top10_data %>%
  mutate(
    LowerCI = ci$lower,
    UpperCI = ci$upper,
    # Convert to percentage
    Incidence = Incidence * 100,
    LowerCI = LowerCI * 100,
    UpperCI = UpperCI * 100
  )

# Create subtitle text with total safety subjects
subtitle_text <- paste0(
  "n = ", TotalSubjects, " subjects; 95% Clopper-Pearson CIs"
)

ggplot(top10_data, aes(x = Incidence, y = reorder(AETERM, Incidence))) +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = LowerCI, xmax = UpperCI), height = 0.2) +
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = subtitle_text,
    x = "Percentage of Patients (%)",
    y = ""
  ) +
  theme_grey()

ggsave(
  "question_3_tlg/ae_top10_with_ci.png",
  width = 8,
  height = 6
)