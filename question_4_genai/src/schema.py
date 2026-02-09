"""
schema.py

Generates a structured schema description of the ADAE dataset.
This schema is provided to the LLM to map free-text questions
to dataset columns and valid filter values.

Contains:
- generate_ae_schema: creates a string describing relevant ADAE columns
  and observed values for categorical fields.
"""

import pandas as pd

def generate_ae_schema(ae_df: pd.DataFrame) -> str:
    # Extract observed values for key categorical columns
    valid_severities = sorted(ae_df["AESEV"].dropna().unique())
    valid_socs = sorted(ae_df["AESOC"].dropna().unique())
    valid_arms = sorted(ae_df["ARM"].dropna().unique()) if "ARM" in ae_df.columns else []
    valid_actarms = sorted(ae_df["ACTARM"].dropna().unique()) if "ACTARM" in ae_df.columns else []

    # Compose schema string
    schema = f"""
Dataset Schema:
---------------
Columns:
- USUBJID: Unique subject identifier
- STUDYID: Study identifier
- DOMAIN: SDTM domain (should be 'AE')
- AESEQ: AE sequence number
- AETERM: Adverse event term (example: Headache)
- AEDECOD: MedDRA dictionary term
- AESOC: Adverse event body system. Observed values: {valid_socs}
- AESEV: Adverse event severity. Observed values: {valid_severities}
- AESER: Serious AE flag (Y/N)
- ARM: Planned treatment arm. Observed values: {valid_arms}
- ACTARM: Actual treatment arm received. Observed values: {valid_actarms}
- TRTSDTM: Treatment start datetime
- TRTEDT: Treatment end date
- SAFFL: Safety population flag (Y/N)
- Additional columns: AEBODSYS, AELLT, AEHLT, AEHLGT, AESOCCD, AESTDTC, AEENDTC

Instructions:
1. Map the user's question to a target column and filter value.
2. Return only valid JSON with keys: "target_column", "filter_value".
3. Example output: {{"target_column": "<COLUMN>", "filter_value": "<VALUE>"}}
"""
    return schema.strip()
