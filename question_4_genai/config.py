"""
config.py

Central configuration for the GenAI Clinical Data Assistant.

Contains:
- Dataset paths
- LLM model selection
- Log file location
- Environment validation
"""

import os

# Path to the ADAE dataset
AE_DATA_PATH = "data/adae.csv"

# Gemini model selection (stable free-tier)
GEMINI_MODEL = "gemini-2.5-flash"

# Log file for persisting executed queries
LOG_FILE = "log.txt"  # Can be "logs/log.txt" if you want a subfolder

# Validate environment variable for Gemini API
if not os.getenv("GEMINI_API_KEY"):
    raise EnvironmentError("GEMINI_API_KEY environment variable is not set.")
