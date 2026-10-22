
-- ============================================================
-- ROSSMANN STORE HEALTH & EARLY WARNING SYSTEM
-- ============================================================

-- Business Objective:
-- Identify stores showing early signs of sales deterioration
-- by monitoring performance, trends, and peer comparisons.

-- Project Framework:
-- Business Performance → Problem Detection → Diagnosis
-- → Forecast → Action

-- ============================================================
-- PART 1: STORE PERFORMANCE METRICS
-- ============================================================

USE rossmann;

-- ============================================================
-- 1.1 Store Performance Metrics
-- ============================================================

-- Calculate key performance metrics for each store.
-- Only operating days are included to ensure
-- comparable average daily performance.

SELECT
    f.store_id,
    s.store_type,
    s.assortment,

    COUNT(*) AS open_days,

    ROUND(
        AVG(f.sales),
        2
    ) AS avg_daily_sales,

    ROUND(
        AVG(f.customers),
        0
    ) AS avg_daily_customers,

    ROUND(
        SUM(f.sales) / NULLIF(SUM(f.customers), 0),
        2
    ) AS sales_per_customer

FROM fact_daily_sales f

JOIN dim_store s
    ON f.store_id = s.store_id

WHERE f.open = 1

GROUP BY
    f.store_id,
    s.store_type,
    s.assortment

ORDER BY
    f.store_id;



-- Check total stores and stores with operating days

SELECT
    COUNT(DISTINCT f.store_id) AS total_stores,
    COUNT(*) AS total_open_day_records

FROM fact_daily_sales f

JOIN dim_store s
    ON f.store_id = s.store_id

WHERE f.open = 1;

    -- ============================================================
-- 1.2 Store Performance Metrics - Quality Check
-- ============================================================

WITH store_metrics AS (
    SELECT
        f.store_id,
        s.store_type,
        s.assortment,

        COUNT(*) AS open_days,

        AVG(f.sales) AS avg_daily_sales,

        AVG(f.customers) AS avg_daily_customers,

        SUM(f.sales) / NULLIF(SUM(f.customers), 0)
            AS sales_per_customer

    FROM fact_daily_sales f

    JOIN dim_store s
        ON f.store_id = s.store_id

    WHERE f.open = 1

    GROUP BY
        f.store_id,
        s.store_type,
        s.assortment
)

SELECT
    COUNT(*) AS total_rows,

    COUNT(DISTINCT store_id) AS unique_stores,

    COUNT(*) - COUNT(DISTINCT store_id)
        AS duplicate_store_ids,

    SUM(
        CASE
            WHEN avg_daily_sales IS NULL
              OR avg_daily_customers IS NULL
              OR sales_per_customer IS NULL
            THEN 1
            ELSE 0
        END
    ) AS stores_with_null_metrics,

    SUM(
        CASE
            WHEN avg_daily_sales < 0
              OR avg_daily_customers < 0
              OR sales_per_customer < 0
            THEN 1
            ELSE 0
        END
    ) AS stores_with_negative_metrics,

    MIN(open_days) AS min_open_days,
    MAX(open_days) AS max_open_days

FROM store_metrics;

-- ============================================================
-- 1.3 Store Performance Metrics - KPI Validation
-- ============================================================

SELECT
    f.store_id,

    ROUND(AVG(f.sales), 2)
        AS avg_daily_sales,

    ROUND(AVG(f.customers), 0)
        AS avg_daily_customers,

    ROUND(
        SUM(f.sales) / NULLIF(SUM(f.customers), 0),
        2
    ) AS sales_per_customer

FROM fact_daily_sales f

WHERE f.open = 1
  AND f.store_id IN (817, 307, 733, 543, 842, 769)

GROUP BY f.store_id

ORDER BY f.store_id;

-- ============================================================
-- 1.4 Create Store Performance View
-- ============================================================

-- Store-level historical performance metrics.
-- One row per store.
-- Only operating days are included.
-- Keep full calculation precision for downstream analysis.

CREATE OR REPLACE VIEW vw_store_performance AS

SELECT
    f.store_id,
    s.store_type,
    s.assortment,

    COUNT(*) AS open_days,

    AVG(f.sales) AS avg_daily_sales,

    AVG(f.customers) AS avg_daily_customers,

    SUM(f.sales) / NULLIF(SUM(f.customers), 0)
        AS sales_per_customer

FROM fact_daily_sales f

JOIN dim_store s
    ON f.store_id = s.store_id

WHERE f.open = 1

GROUP BY
    f.store_id,
    s.store_type,
    s.assortment;

    -- ============================================================
-- 1.5 Validate Store Performance View
-- ============================================================

SELECT
    COUNT(*) AS total_stores,
    COUNT(DISTINCT store_id) AS unique_stores

FROM vw_store_performance;