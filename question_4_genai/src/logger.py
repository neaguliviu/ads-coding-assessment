"""
logger.py

Logs questions and their results to a text file with timestamps.

Contains:
- log_result: appends question and results to LOG_FILE for reproducibility.
"""

from config import LOG_FILE
import os
from datetime import datetime

# Ensure log directory exists if LOG_FILE has a folder path
log_dir = os.path.dirname(LOG_FILE)
if log_dir:  # Only create a directory if it's not empty
    os.makedirs(log_dir, exist_ok=True)

def log_result(question: str, result: dict) -> None:
    """Append the question and result to the log file with a timestamp."""
    timestamp = datetime.now().isoformat()
    with open(LOG_FILE, "a", encoding="utf-8") as file:
        file.write(f"[{timestamp}] Question: {question}\n")
        file.write(f"Result: {result}\n")
        file.write("-" * 60 + "\n")
