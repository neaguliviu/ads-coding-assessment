"""
main.py

End-to-end workflow for the GenAI Clinical Data Assistant.

Workflow:
1. Load ADAE dataset
2. Generate schema for LLM
3. Process natural language questions
4. Convert questions -> structured JSON via LLM
5. Execute queries on dataset
6. Print results to console including Pandas filter
7. Log results for reproducibility
"""

import pandas as pd
from src import llm_utils, schema, executor, logger
from config import AE_DATA_PATH
from config import LOG_FILE
from datetime import datetime

# Clear the log at the start of this run
with open(LOG_FILE, "w", encoding="utf-8") as f:
    f.write(f"Log started: {datetime.now().isoformat()}\n")
    f.write("="*60 + "\n")

# Load ADAE dataset
ae_df = pd.read_csv(AE_DATA_PATH)

# Generate LLM schema string
ae_schema = schema.generate_ae_schema(ae_df)

# Example questions
questions = [
    "Give me the subjects who had adverse events of Moderate severity",
    "Which subjects experienced Headache?",
    "Show subjects with Cardiac related adverse events"
]

for question in questions:
    print(f"\n[Question]: {question}")

    try:
        # Convert question to structured query using LLM
        query = llm_utils.clinical_trial_data_agent(question, ae_schema)

        # Execute query on dataset
        result = executor.execute_query(ae_df, query)

        # Print results
        if not result["status"].startswith("Success"):
            print(f"  -> {result['status']}")
        else:
            print(f"  -> Target column: {result['target_column']}, Filter value: '{result['filter_value']}'")
            print(f"  -> Pandas query: {result['pandas_filter']}")
            print(f"  -> Unique subjects: {result['unique_subject_count']}")
            print(f"  -> Sample IDs (first 10): {result['subjects_console']}")

        # Log results
        logger.log_result(question, result)

    except Exception as exc:
        print(f"  -> Error processing question: {exc}")
        logger.log_result(question, {"status": f"Error: {exc}"})
