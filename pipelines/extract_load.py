"""
Extract and Load Pipeline: Raw CSV → Parquet (partitioned by event_date)

This script processes raw CSV files from Kaggle E-commerce dataset using DuckDB
and saves them as partitioned Parquet files for efficient querying.

Features:
- Incremental loading (only processes new files)
- Data validation and cleaning
- Partitioned output by event_date
"""
import argparse
import duckdb
from pathlib import Path
from tqdm import tqdm

from utils import (
    logger, 
    RAW_DIR, INTERIM_DIR, PROCESSED_DIR,
    ensure_dirs, get_raw_files, load_state, save_state, get_unprocessed_files
)


def process_csv_to_parquet(
    csv_path: Path,
    output_dir: Path,
    sample_weeks: int = None,
    conn: duckdb.DuckDBPyConnection = None
) -> dict:
    """
    Process a single CSV file to partitioned Parquet.
    
    Args:
        csv_path: Path to raw CSV file
        output_dir: Directory for Parquet output
        sample_weeks: If set, only process this many weeks (for MVP)
        conn: DuckDB connection (optional)
    
    Returns:
        dict with processing statistics
    """
    logger.info(f"Processing: {csv_path.name}")
    
    if conn is None:
        conn = duckdb.connect()
    
    # Read CSV and perform transformations
    # DuckDB auto-detects event_time as timestamp, so we use it directly
    query = f"""
    WITH raw_events AS (
        SELECT 
            *,
            -- event_time is auto-parsed as timestamp by DuckDB
            CAST(event_time AS TIMESTAMP) AS event_timestamp
        FROM read_csv_auto('{csv_path}', header=true, sample_size=100000)
    ),
    validated_events AS (
        SELECT
            event_timestamp,
            CAST(event_timestamp AS DATE) AS event_date,
            event_type,
            product_id,
            category_id,
            category_code,
            brand,
            price,
            user_id,
            user_session,
            -- Validation flags
            CASE 
                WHEN event_type NOT IN ('view', 'cart', 'purchase') THEN true 
                ELSE false 
            END AS is_invalid_event_type,
            CASE 
                WHEN price IS NULL OR price < 0 OR price > 100000 THEN true 
                ELSE false 
            END AS is_invalid_price
        FROM raw_events
        WHERE event_timestamp IS NOT NULL
    )
    SELECT 
        event_timestamp,
        event_date,
        event_type,
        product_id,
        category_id,
        category_code,
        brand,
        CASE WHEN is_invalid_price THEN NULL ELSE price END AS price,
        user_id,
        user_session
    FROM validated_events
    WHERE NOT is_invalid_event_type
    """
    
    # Add week limit for sampling if specified
    if sample_weeks:
        query = f"""
        WITH base AS ({query})
        SELECT * FROM base
        WHERE event_date <= (SELECT MIN(event_date) + INTERVAL '{sample_weeks * 7} days' FROM base)
        """
    
    # Get statistics before filtering
    stats_query = f"""
    WITH raw_events AS (
        SELECT 
            *,
            CAST(event_time AS TIMESTAMP) AS event_timestamp
        FROM read_csv_auto('{csv_path}', header=true, sample_size=100000)
    )
    SELECT 
        COUNT(*) AS total_rows,
        COUNT(CASE WHEN event_type NOT IN ('view', 'cart', 'purchase') THEN 1 END) AS invalid_event_type_count,
        COUNT(CASE WHEN price IS NULL OR price < 0 OR price > 100000 THEN 1 END) AS invalid_price_count,
        MIN(event_timestamp) AS min_time,
        MAX(event_timestamp) AS max_time
    FROM raw_events
    """
    
    logger.info("Collecting statistics...")
    stats = conn.execute(stats_query).fetchone()
    total_rows, invalid_events, invalid_prices, min_time, max_time = stats
    
    logger.info(f"  Total rows: {total_rows:,}")
    logger.info(f"  Invalid event types: {invalid_events:,}")
    logger.info(f"  Invalid prices: {invalid_prices:,}")
    logger.info(f"  Date range: {min_time} to {max_time}")
    
    # Create temp table with processed data
    logger.info("Processing data...")
    conn.execute(f"CREATE OR REPLACE TABLE processed_events AS {query}")
    
    # Get processed row count
    processed_count = conn.execute("SELECT COUNT(*) FROM processed_events").fetchone()[0]
    logger.info(f"  Processed rows: {processed_count:,}")
    
    # Export to partitioned Parquet
    logger.info("Exporting to Parquet...")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Get unique dates and export partition by partition
    dates = conn.execute("""
        SELECT DISTINCT event_date 
        FROM processed_events 
        ORDER BY event_date
    """).fetchall()
    
    for (event_date,) in tqdm(dates, desc="Writing partitions"):
        partition_dir = output_dir / f"event_date={event_date}"
        partition_dir.mkdir(parents=True, exist_ok=True)
        partition_file = partition_dir / "data.parquet"
        
        conn.execute(f"""
            COPY (
                SELECT * FROM processed_events 
                WHERE event_date = '{event_date}'
            ) TO '{partition_file}' (FORMAT PARQUET, COMPRESSION ZSTD)
        """)
    
    # Cleanup
    conn.execute("DROP TABLE IF EXISTS processed_events")
    
    return {
        "file": csv_path.name,
        "total_rows": total_rows,
        "processed_rows": processed_count,
        "invalid_event_types": invalid_events,
        "invalid_prices": invalid_prices,
        "date_range": f"{min_time} to {max_time}",
        "partitions": len(dates)
    }


def run_pipeline(
    full_refresh: bool = False,
    sample_weeks: int = None
) -> dict:
    """
    Run the extract and load pipeline.
    
    Args:
        full_refresh: If True, reprocess all files
        sample_weeks: If set, only process this many weeks per file
    
    Returns:
        dict with overall statistics
    """
    ensure_dirs()
    
    # Load state
    state = load_state() if not full_refresh else {"last_processed_files": []}
    
    # Get files to process
    files_to_process = get_unprocessed_files(state) if not full_refresh else get_raw_files()
    
    if not files_to_process:
        logger.info("No new files to process")
        return {"status": "no_new_files"}
    
    logger.info(f"Files to process: {[f.name for f in files_to_process]}")
    
    # Create DuckDB connection with memory limit
    conn = duckdb.connect(str(INTERIM_DIR / "pipeline.duckdb"))
    conn.execute("SET memory_limit='4GB'")
    conn.execute("SET threads=4")
    
    results = []
    total_processed = 0
    
    try:
        for csv_file in files_to_process:
            result = process_csv_to_parquet(
                csv_path=csv_file,
                output_dir=PROCESSED_DIR,
                sample_weeks=sample_weeks,
                conn=conn
            )
            results.append(result)
            total_processed += result["processed_rows"]
            
            # Update state
            state["last_processed_files"].append(csv_file.name)
        
        # Save final state
        state["total_rows_processed"] = state.get("total_rows_processed", 0) + total_processed
        save_state(state)
        
        logger.info(f"\n{'='*50}")
        logger.info(f"Pipeline completed successfully!")
        logger.info(f"Total rows processed: {total_processed:,}")
        logger.info(f"Output directory: {PROCESSED_DIR}")
        
    finally:
        conn.close()
    
    return {
        "status": "success",
        "files_processed": len(results),
        "total_rows": total_processed,
        "results": results
    }


def main():
    parser = argparse.ArgumentParser(description="Extract and Load Pipeline")
    parser.add_argument(
        "--full-refresh", 
        action="store_true",
        help="Reprocess all files (ignore previous state)"
    )
    parser.add_argument(
        "--sample-weeks",
        type=int,
        default=None,
        help="Only process first N weeks of data (for MVP development)"
    )
    args = parser.parse_args()
    
    result = run_pipeline(
        full_refresh=args.full_refresh,
        sample_weeks=args.sample_weeks
    )
    
    if result["status"] == "success":
        logger.info(f"\nProcessed {result['files_processed']} file(s)")
        for r in result["results"]:
            logger.info(f"  - {r['file']}: {r['processed_rows']:,} rows, {r['partitions']} partitions")


if __name__ == "__main__":
    main()
