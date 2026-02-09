"""
llm_utils.py

Handles communication with the Gemini LLM to convert free-text questions
into structured queries containing the target column and filter value.

Contains:
- clinical_trial_data_agent: sends the question and dataset schema to the LLM and parses JSON response
"""

import json
from google import genai
from config import GEMINI_MODEL

# Initialize Gemini client
client = genai.Client()

def clinical_trial_data_agent(question: str, schema: str) -> dict:
    # Construct prompt for LLM
    prompt = f"""
{schema}

User Question:
"{question}"

Return JSON only with keys "target_column" and "filter_value".
"""

    # Call the Gemini model
    response = client.models.generate_content(model=GEMINI_MODEL, contents=prompt)

    # Extract raw text and remove Markdown code fences
    raw_output = response.text.strip().replace("```json", "").replace("```", "").strip()

    # Parse JSON
    try:
        result = json.loads(raw_output)
    except json.JSONDecodeError as exc:
        raise ValueError(f"LLM returned invalid JSON:\n{raw_output}") from exc

    # Validate expected keys
    if "target_column" not in result or "filter_value" not in result:
        raise ValueError(f"JSON missing required keys:\n{raw_output}")

    return result
