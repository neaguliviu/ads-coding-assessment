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
from pathlib import Path
from dotenv import load_dotenv

# Load .env from the same directory as this file
env_path = Path(__file__).parent / ".env"
load_dotenv(env_path, override=True)

# Path to the ADAE dataset
AE_DATA_PATH = "data/adae.csv"

# Gemini model selection (stable free-tier)
GEMINI_MODEL = "gemini-2.5-flash"

# Log file for persisting executed queries
LOG_FILE = "log.txt"  # Can be "logs/log.txt" if you want a subfolder

# Validate environment variable for Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise EnvironmentError(
        "GEMINI_API_KEY not found. "
        "Make sure question_4_genai/.env exists and is loaded."
    )