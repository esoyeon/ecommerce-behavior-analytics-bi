"""Utility functions for the data pipeline."""
import os
import json
import logging
from pathlib import Path
from datetime import datetime
from typing import Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
INTERIM_DIR = DATA_DIR / "interim"
PROCESSED_DIR = DATA_DIR / "processed"
STATE_FILE = INTERIM_DIR / "state.json"


def ensure_dirs():
    """Ensure all required directories exist."""
    for d in [RAW_DIR, INTERIM_DIR, PROCESSED_DIR]:
        d.mkdir(parents=True, exist_ok=True)


def get_raw_files() -> list[Path]:
    """Get list of raw CSV files sorted by name."""
    if not RAW_DIR.exists():
        return []
    return sorted(RAW_DIR.glob("*.csv"))


def load_state() -> dict:
    """Load pipeline state from state.json."""
    if STATE_FILE.exists():
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    return {
        "last_processed_files": [],
        "last_processed_time": None,
        "total_rows_processed": 0
    }


def save_state(state: dict):
    """Save pipeline state to state.json."""
    ensure_dirs()
    state["last_updated"] = datetime.now().isoformat()
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2, default=str)
    logger.info(f"State saved to {STATE_FILE}")


def get_unprocessed_files(state: dict) -> list[Path]:
    """Get list of files not yet processed."""
    processed = set(state.get("last_processed_files", []))
    all_files = get_raw_files()
    return [f for f in all_files if f.name not in processed]


def get_db_connection_string() -> str:
    """Get PostgreSQL connection string from environment."""
    from dotenv import load_dotenv
    load_dotenv(PROJECT_ROOT / ".env")
    
    user = os.getenv("POSTGRES_USER", "retail")
    password = os.getenv("POSTGRES_PASSWORD", "retail_password")
    host = os.getenv("POSTGRES_HOST", "localhost")
    port = os.getenv("POSTGRES_PORT", "5432")
    db = os.getenv("POSTGRES_DB", "retail_db")
    
    return f"postgresql://{user}:{password}@{host}:{port}/{db}"
