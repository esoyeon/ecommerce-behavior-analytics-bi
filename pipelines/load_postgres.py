"""
Load Parquet data to PostgreSQL for BI access.

This script loads processed Parquet files into PostgreSQL,
creating appropriate tables and indexes for Metabase queries.
"""
import argparse
import duckdb
from sqlalchemy import create_engine, text
from pathlib import Path

from utils import (
    logger, 
    PROCESSED_DIR,
    get_db_connection_string
)


def create_tables(engine):
    """Create tables and indexes in PostgreSQL."""
    
    with engine.connect() as conn:
        # Create staging schema tables
        conn.execute(text("""
            DROP TABLE IF EXISTS staging.stg_events CASCADE;
            CREATE TABLE staging.stg_events (
                event_timestamp TIMESTAMP,
                event_date DATE,
                event_type VARCHAR(20),
                product_id BIGINT,
                category_id BIGINT,
                category_code VARCHAR(255),
                brand VARCHAR(100),
                price DECIMAL(12, 2),
                user_id BIGINT,
                user_session VARCHAR(50)
            );
        """))
        
        conn.commit()
        logger.info("Created staging.stg_events table")


def create_indexes(engine):
    """Create indexes for query performance."""
    
    indexes = [
        "CREATE INDEX IF NOT EXISTS idx_stg_events_date ON staging.stg_events(event_date)",
        "CREATE INDEX IF NOT EXISTS idx_stg_events_user ON staging.stg_events(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_stg_events_date_user ON staging.stg_events(event_date, user_id)",
        "CREATE INDEX IF NOT EXISTS idx_stg_events_session ON staging.stg_events(user_session)",
        "CREATE INDEX IF NOT EXISTS idx_stg_events_product ON staging.stg_events(product_id)",
        "CREATE INDEX IF NOT EXISTS idx_stg_events_type ON staging.stg_events(event_type)",
    ]
    
    with engine.connect() as conn:
        for idx_sql in indexes:
            conn.execute(text(idx_sql))
        conn.commit()
    
    logger.info(f"Created {len(indexes)} indexes")


def load_parquet_to_postgres(sample_days: int = None):
    """
    Load Parquet files to PostgreSQL.
    
    Args:
        sample_days: If set, only load this many days of data
    """
    # Check if processed data exists
    if not PROCESSED_DIR.exists():
        logger.error(f"Processed directory not found: {PROCESSED_DIR}")
        logger.error("Run extract_load.py first to generate Parquet files")
        return
    
    # Get all partition directories
    partitions = sorted(PROCESSED_DIR.glob("event_date=*/data.parquet"))
    
    if not partitions:
        logger.error("No Parquet partitions found")
        return
    
    logger.info(f"Found {len(partitions)} date partitions")
    
    # Limit partitions for sampling
    if sample_days:
        partitions = partitions[:sample_days]
        logger.info(f"Sampling first {sample_days} days")
    
    # Create SQLAlchemy engine
    conn_string = get_db_connection_string()
    engine = create_engine(conn_string)
    
    # Create tables
    create_tables(engine)
    
    # Use DuckDB to read Parquet and insert to Postgres
    duck_conn = duckdb.connect()
    duck_conn.execute("INSTALL postgres; LOAD postgres;")
    duck_conn.execute(f"ATTACH '{conn_string}' AS pg (TYPE postgres)")
    
    total_rows = 0
    
    for partition_file in partitions:
        # Extract date from path
        date_str = partition_file.parent.name.replace("event_date=", "")
        logger.info(f"Loading partition: {date_str}")
        
        # Read and insert
        row_count = duck_conn.execute(f"""
            INSERT INTO pg.staging.stg_events
            SELECT * FROM read_parquet('{partition_file}');
            SELECT COUNT(*) FROM read_parquet('{partition_file}');
        """).fetchone()[0]
        
        total_rows += row_count
        logger.info(f"  Loaded {row_count:,} rows")
    
    duck_conn.close()
    
    # Create indexes after data load
    logger.info("Creating indexes...")
    create_indexes(engine)
    
    logger.info(f"\n{'='*50}")
    logger.info(f"Data load completed!")
    logger.info(f"Total rows loaded: {total_rows:,}")
    
    # Verify load
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT 
                COUNT(*) AS total_rows,
                COUNT(DISTINCT user_id) AS unique_users,
                COUNT(DISTINCT product_id) AS unique_products,
                MIN(event_date) AS min_date,
                MAX(event_date) AS max_date
            FROM staging.stg_events
        """)).fetchone()
        
        logger.info(f"\nData Summary:")
        logger.info(f"  Total rows: {result[0]:,}")
        logger.info(f"  Unique users: {result[1]:,}")
        logger.info(f"  Unique products: {result[2]:,}")
        logger.info(f"  Date range: {result[3]} to {result[4]}")


def main():
    parser = argparse.ArgumentParser(description="Load Parquet to PostgreSQL")
    parser.add_argument(
        "--sample-days",
        type=int,
        default=None,
        help="Only load first N days of data"
    )
    args = parser.parse_args()
    
    load_parquet_to_postgres(sample_days=args.sample_days)


if __name__ == "__main__":
    main()
