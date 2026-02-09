"""
executor.py

Executes structured queries on the ADAE dataset.

This module:

- Extracts target column and filter value from LLM output.
- Attempts direct exact match first (using the filter value as-is).
- Falls back to uppercase-normalized exact match if no direct match is found.
- Falls back to case-insensitive partial match using str.contains as the last resort.
- Returns unique subject counts, sample IDs, and the applied Pandas query for transparency.
"""

import pandas as pd

def execute_query(ae_df: pd.DataFrame, query: dict) -> dict:
    # Extract target column and filter value from LLM output
    column = query.get("target_column")
    value = query.get("filter_value")

    # Validate that column exists
    if column not in ae_df.columns:
        return {"status": f"Invalid target column: {column}"}

    # Step 1: Direct match using the LLM-provided filter value
    mask = ae_df[column] == value
    pandas_filter = f'ae_df["{column}"] == "{value}"'
    fallback_used = False  # Track if we need fallback

    # Step 2: Fallback to uppercase-normalized match if direct match fails
    if not mask.any():
        column_upper = ae_df[column].astype(str).str.upper()
        value_upper = str(value).upper()
        if value_upper in column_upper.values:
            mask = column_upper == value_upper
            pandas_filter = f'ae_df["{column}"].astype(str).str.upper() == "{value_upper}"'
            fallback_used = True

    # Step 3: Fallback to case-insensitive partial match if no match yet
    if not mask.any():
        mask = ae_df[column].astype(str).str.contains(str(value), case=False, na=False)
        pandas_filter = f'ae_df["{column}"].astype(str).str.contains("{value}", case=False, na=False)'
        fallback_used = True

    # Apply mask to filter dataset
    filtered = ae_df[mask]

    # Get unique subject IDs
    subjects = filtered["USUBJID"].unique().tolist()

    # Prepare status message
    status = "Success" if subjects else "No subjects found"
    if fallback_used and subjects:
        status += " (fallback match applied)"

    # Return results including the applied Pandas query
    return {
        "status": status,
        "target_column": column,
        "filter_value": value,
        "pandas_filter": pandas_filter,
        "unique_subject_count": len(subjects),
        "subjects_console": subjects[:10],
        "subjects_full": subjects
    }
