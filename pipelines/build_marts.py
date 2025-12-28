"""
Build and validate marts after dbt run.

This script provides validation checks for the marts tables
and can be used for data quality monitoring.
"""
import argparse
from sqlalchemy import create_engine, text
from tabulate import tabulate

from utils import logger, get_db_connection_string


def validate_marts():
    """Run validation checks on marts tables."""
    
    conn_string = get_db_connection_string()
    engine = create_engine(conn_string)
    
    checks = [
        # Row counts
        {
            "name": "Row counts",
            "sql": """
                SELECT 'staging.stg_events' AS table_name, COUNT(*) AS row_count FROM staging.stg_events
                UNION ALL
                SELECT 'marts.fact_events', COUNT(*) FROM marts.fact_events
                UNION ALL
                SELECT 'marts.fact_sessions', COUNT(*) FROM marts.fact_sessions
                UNION ALL
                SELECT 'marts.mart_funnel_daily', COUNT(*) FROM marts.mart_funnel_daily
                UNION ALL
                SELECT 'marts.mart_retention_cohort_weekly', COUNT(*) FROM marts.mart_retention_cohort_weekly
                UNION ALL
                SELECT 'marts.mart_category_growth_weekly', COUNT(*) FROM marts.mart_category_growth_weekly
            """
        },
        # Date range
        {
            "name": "Date range (fact_events)",
            "sql": """
                SELECT 
                    MIN(event_date) AS min_date,
                    MAX(event_date) AS max_date,
                    COUNT(DISTINCT event_date) AS days
                FROM marts.fact_events
            """
        },
        # Event type distribution
        {
            "name": "Event type distribution",
            "sql": """
                SELECT 
                    event_type,
                    COUNT(*) AS count,
                    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
                FROM marts.fact_events
                GROUP BY event_type
                ORDER BY count DESC
            """
        },
        # User type distribution
        {
            "name": "User type distribution",
            "sql": """
                SELECT 
                    user_type,
                    COUNT(DISTINCT user_id) AS users,
                    ROUND(COUNT(DISTINCT user_id) * 100.0 / 
                          SUM(COUNT(DISTINCT user_id)) OVER(), 2) AS pct
                FROM marts.fact_events
                GROUP BY user_type
            """
        },
        # Funnel overview (latest day)
        {
            "name": "Funnel overview (latest day)",
            "sql": """
                SELECT 
                    SUM(view_users) AS view_users,
                    SUM(cart_users) AS cart_users,
                    SUM(purchase_users) AS purchase_users,
                    ROUND(SUM(cart_users) * 100.0 / NULLIF(SUM(view_users), 0), 2) AS cart_rate,
                    ROUND(SUM(purchase_users) * 100.0 / NULLIF(SUM(view_users), 0), 2) AS purchase_rate
                FROM marts.mart_funnel_daily
                WHERE event_date = (SELECT MAX(event_date) FROM marts.mart_funnel_daily)
            """
        },
        # Retention overview (first cohort)
        {
            "name": "Retention overview (first cohort)",
            "sql": """
                SELECT 
                    cohort_week,
                    week_number,
                    cohort_size,
                    active_users,
                    retention_rate_pct
                FROM marts.mart_retention_cohort_weekly
                WHERE cohort_week = (SELECT MIN(cohort_week) FROM marts.mart_retention_cohort_weekly)
                ORDER BY week_number
                LIMIT 8
            """
        },
        # Top categories by revenue
        {
            "name": "Top categories by revenue (latest week)",
            "sql": """
                SELECT 
                    category_l1,
                    revenue,
                    revenue_share_pct,
                    purchasers
                FROM marts.mart_category_growth_weekly
                WHERE event_week = (SELECT MAX(event_week) FROM marts.mart_category_growth_weekly)
                ORDER BY revenue DESC
                LIMIT 10
            """
        }
    ]
    
    with engine.connect() as conn:
        for check in checks:
            logger.info(f"\n{'='*50}")
            logger.info(f"CHECK: {check['name']}")
            logger.info('='*50)
            
            try:
                result = conn.execute(text(check['sql']))
                rows = result.fetchall()
                columns = result.keys()
                
                if rows:
                    print(tabulate(rows, headers=columns, tablefmt='psql'))
                else:
                    logger.warning("No data returned")
            except Exception as e:
                logger.error(f"Error: {e}")
    
    logger.info("\n" + "="*50)
    logger.info("Validation complete!")


def main():
    parser = argparse.ArgumentParser(description="Validate marts tables")
    parser.add_argument(
        "--check",
        type=str,
        default="all",
        help="Specific check to run (default: all)"
    )
    args = parser.parse_args()
    
    validate_marts()


if __name__ == "__main__":
    main()
