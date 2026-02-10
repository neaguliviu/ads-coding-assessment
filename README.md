## ADS Programmer Coding Assessment

**Candidate:** Liviu Neagu 

**Focus:** Pharmaverse Ecosystem (R) & GenAI Integration (Python)

---

### 📖 Overview

This repository contains solutions for the coding assessment, covering both R-based SDTM/ADaM/TLG tasks and a Python GenAI Clinical Data Assistant. Each question is self-contained in its own folder with data, scripts and logs for reproducibility.

* **Question 1: SDTM Transformation** – Maps raw data into CDISC SDTM domains using {sdtm.oak}.
* **Question 2: ADaM Derivation** – Creates subject-level ADSL datasets using {admiral} and {tidyverse}.
* **Question 3: Reporting (TLG)** – Generates FDA-style tables using {gtsummary} and visualizations using {ggplot2}.
* **Question 4: GenAI Assistant** – Python-based assistant for querying clinical data using natural language.

---

### 📂 Repository Structure

```text
.
├── .gitignore                     # Git ignore rules
├── .Rprofile                      # R project profile settings
├── project.Rproj                  # RStudio project file
├── renv.lock                      # R dependency lockfile
├── data/
│   └── study_ct.csv               # Controlled terminology for SDTM DS derivation
├── question_1_sdtm/
│   ├── 01_create_ds_domain.R      # R script to generate DS domain
│   ├── ds_final.csv               # Output SDTM DS dataset
│   └── question_1_log.txt         # Execution log
├── question_2_adam/
│   ├── create_adsl.R              # R script to derive ADSL dataset
│   ├── adsl_final.csv             # Output ADaM ADSL dataset
│   └── question_2_log.txt         # Execution log
├── question_3_tlg/
│   ├── 01_create_ae_summary_table.R  # R script to generate AE summary table
│   ├── 02_create_ae_visualizations.R # R script to generate AE plots
│   ├── 03_question_3_driver.R        # Driver script to run both AE scripts
│   ├── ae_summary_table.html         # FDA Table 10 style summary
│   ├── ae_severity_by_treatment.png  # AE severity distribution plot
│   ├── ae_top10_with_ci.png          # Top 10 AE plot with 95% CI
│   └── question_3_log.txt            # Execution log
├── question_4_genai/
│   ├── main.py                    # Entry point for GenAI assistant
│   ├── config.py                  # Configuration (paths, GEMINI_API_KEY)
│   ├── requirements.txt           # Python dependencies
│   ├── log.txt                    # Query audit log
│   ├── data/
│   │   └── adae.csv               # ADAE dataset for querying
│   ├── scripts/
│   │   └── export_adae.R          # Optional R export script
│   └── src/
│       ├── __init__.py            # Python package init
│       ├── executor.py            # Executes pandas queries with fallback logic
│       ├── llm_utils.py           # Interfaces with Gemini API to parse questions
│       ├── logger.py              # Logs questions and results
│       └── schema.py              # Generates dataset schema for LLM grounding
```
### 🛠️ Setup & Run Instructions

#### R Workflow (Questions 1-3)

1. Open `project.Rproj` in RStudio or Posit Cloud.
2. Restore the R environment by running the following in the R console:
   `renv::restore()`
3. Run each script:
   - `source("question_1_sdtm/01_create_ds_domain.R", echo = FALSE)`
   - `source("question_2_adam/create_adsl.R", echo = FALSE)`
   - `source("question_3_tlg/03_question_3_driver.R", echo = FALSE)`
4. Outputs and log files are stored in the corresponding folders.

#### Python Workflow (Question 4)

1. Navigate to the folder:
   `cd question_4_genai`
2. Create and activate a virtual environment:
   **Linux/Mac**
   `python3 -m venv venv`
   `source venv/bin/activate`
   **Windows**
   `python -m venv venv`
   `venv\Scripts\activate`
3. Install dependencies:
   `pip install -r requirements.txt`
4. Create a `.env` file in `question_4_genai/` with your Gemini API key:
   `GEMINI_API_KEY="your_api_key_here"`
5. Run the GenAI assistant:
   `python main.py`
6. The results appear in the terminal and are also saved to `question_4_genai/log.txt`.

---

#### ✅ Notes & Best Practices

- **Traceability:** Scripts generate log files for traceability.
- **Modularity:** Solutions are self-contained, with the Python workflow following a modular `src/` structure.
- **Documentation:** Code is documented clearly for readability and maintainability.