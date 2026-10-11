-- ============================================================
-- Olist Brazilian E-Commerce — Delivery Performance Diagnostic
-- ============================================================
-- Purpose : Investigate where late deliveries concentrate and
--           what they cost the business in customer satisfaction.
-- Approach: Baseline → geographic concentration → mechanism →
--           business impact → recommendation.
-- Metric  : late = order_delivered_customer_date >
--           order_estimated_delivery_date
-- Note    : Undelivered orders excluded from rate calculations;
--           count reported separately.
-- ============================================================


-- ------------------------------------------------------------
-- Query 1 — Baseline: overall late rate
-- ------------------------------------------------------------
-- Question: What proportion of delivered orders arrive after
--           the estimated delivery date?

SELECT
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
             THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                         THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS late_rate_pct
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;


-- ------------------------------------------------------------
-- Query 2 — Does late rate vary by customer state?
-- ------------------------------------------------------------
-- Question: Is lateness uniform across Brazil, or concentrated?
-- Answer  : Concentrated. Northeast states (AL, MA, PI, CE, SE)
--           show 15–24% late vs 3–6% in South/Southeast.

SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
             THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                         THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS late_rate_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 200
ORDER BY late_rate_pct DESC;


-- ------------------------------------------------------------
-- Query 3 — Is the problem distance, or the buffer?
-- ------------------------------------------------------------
-- Question: Do the worst states have longer actual delivery
--           times, or is the issue insufficient estimated
--           delivery buffer?
-- Answer  : Buffer, not distance. Under-buffered states have
--           15–24% late rates even when geographically closer
--           than well-buffered states.

SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)), 1) AS avg_delivery_days,
    ROUND(AVG(julianday(o.order_estimated_delivery_date) - julianday(o.order_purchase_timestamp)), 1) AS avg_estimated_days,
    ROUND(AVG(julianday(o.order_estimated_delivery_date) - julianday(o.order_delivered_customer_date)), 2) AS avg_buffer_days,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 200
ORDER BY avg_buffer_days ASC;


-- ------------------------------------------------------------
-- Query 4 — Business impact: customer review scores
-- ------------------------------------------------------------
-- Question: Do late deliveries cost the business in customer
--           satisfaction?
-- Answer  : Late orders average 2.57 stars vs 4.29 for on-time.
--           54% of late orders receive 1–2 star reviews vs 9%
--           for on-time.

SELECT
    CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
         THEN 'Late' ELSE 'On-time' END AS delivery_status,
    COUNT(*) AS orders_with_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS low_reviews,
    ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS low_review_pct
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND r.review_score IS NOT NULL
GROUP BY delivery_status;


-- ------------------------------------------------------------
-- Query 5 — Robustness: is the late→low-review link universal?
-- ------------------------------------------------------------
-- Question: Does the review-score gap hold across all states?
-- Answer  : Universal. Late orders score 1.94–3.20 across
--           states; on-time orders score 4.15–4.40 everywhere.

SELECT
    c.customer_state,
    ROUND(AVG(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                   THEN r.review_score END), 2) AS avg_score_late,
    ROUND(AVG(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
                   THEN r.review_score END), 2) AS avg_score_ontime,
    COUNT(*) AS orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND r.review_score IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 200
ORDER BY avg_score_late ASC;