import pandas as pd
import sqlite3
from pathlib import Path

DB_PATH = Path("olist.db")
conn = sqlite3.connect(DB_PATH)

# --- Export 1: State-level summary ---
print("Exporting state-level summary...")
states_query = """
WITH state_metrics AS (
    SELECT
        c.customer_state,
        COUNT(*) AS delivered_orders,
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                 THEN 1 ELSE 0 END) AS late_orders,
        ROUND(100.0 * SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                                THEN 1 ELSE 0 END) / COUNT(*), 2) AS late_rate_pct,
        ROUND(AVG(julianday(o.order_estimated_delivery_date) - julianday(o.order_purchase_timestamp))
              - AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)), 2) AS avg_buffer_days,
        ROUND(AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)), 1) AS avg_delivery_days
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
    GROUP BY c.customer_state
    HAVING COUNT(*) >= 200
)
SELECT * FROM state_metrics
ORDER BY late_rate_pct DESC;
"""
states_df = pd.read_sql_query(states_query, conn)
states_df.to_csv("tableau_states.csv", index=False)
print(f"  -> {len(states_df)} states")

# --- Export 2: Review score by delivery status ---
print("Exporting review comparison...")
reviews_query = """
SELECT
    CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
         THEN 'Late' ELSE 'On-time' END AS delivery_status,
    COUNT(*) AS orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS low_reviews,
    ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS low_review_pct
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND r.review_score IS NOT NULL
GROUP BY delivery_status;
"""
reviews_df = pd.read_sql_query(reviews_query, conn)
reviews_df.to_csv("tableau_reviews.csv", index=False)
print(f"  -> {len(reviews_df)} rows")

# --- Export 3: Order-level for scatter/detail ---
print("Exporting order-level detail...")
orders_query = """
SELECT
    o.order_id,
    c.customer_state,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ROUND(julianday(o.order_estimated_delivery_date) - julianday(o.order_purchase_timestamp), 1) AS estimated_days,
    ROUND(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp), 1) AS actual_days,
    ROUND(julianday(o.order_estimated_delivery_date) - julianday(o.order_delivered_customer_date), 1) AS buffer_days,
    CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
         THEN 1 ELSE 0 END AS late_flag,
    r.review_score
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;
"""
orders_df = pd.read_sql_query(orders_query, conn)
orders_df.to_csv("tableau_orders.csv", index=False)
print(f"  -> {len(orders_df):,} orders")

conn.close()
print("\nDone.")