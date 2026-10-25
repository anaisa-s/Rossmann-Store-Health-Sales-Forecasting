
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

-- ============================================================
-- PART 2: PERFORMANCE MONITORING
-- ============================================================

-- 2.1 Recent Performance Changes
-- Compare the last 8 weeks with the previous 8 weeks.
-- Only operating days are included.

WITH reference_date AS (
    SELECT
        MAX(d.full_date) AS last_date
    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
),

period_metrics AS (
    SELECT
        f.store_id,

        -- Previous 8 weeks
        COUNT(CASE
            WHEN d.full_date <= DATE_SUB(r.last_date, INTERVAL 56 DAY)
            THEN 1
        END) AS previous_open_days,

        AVG(CASE
            WHEN d.full_date <= DATE_SUB(r.last_date, INTERVAL 56 DAY)
            THEN f.sales
        END) AS previous_avg_sales,

        AVG(CASE
            WHEN d.full_date <= DATE_SUB(r.last_date, INTERVAL 56 DAY)
            THEN f.customers
        END) AS previous_avg_customers,

        -- Recent 8 weeks
        COUNT(CASE
            WHEN d.full_date > DATE_SUB(r.last_date, INTERVAL 56 DAY)
            THEN 1
        END) AS recent_open_days,

        AVG(CASE
            WHEN d.full_date > DATE_SUB(r.last_date, INTERVAL 56 DAY)
            THEN f.sales
        END) AS recent_avg_sales,

        AVG(CASE
            WHEN d.full_date > DATE_SUB(r.last_date, INTERVAL 56 DAY)
            THEN f.customers
        END) AS recent_avg_customers

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN reference_date r

    WHERE f.open = 1
      AND d.full_date > DATE_SUB(r.last_date, INTERVAL 112 DAY)
      AND d.full_date <= r.last_date

    GROUP BY f.store_id
)

SELECT
    store_id,
    previous_open_days,
    recent_open_days,

    ROUND(previous_avg_sales, 2) AS previous_avg_sales,
    ROUND(recent_avg_sales, 2) AS recent_avg_sales,

    ROUND(
        100.0 * (recent_avg_sales - previous_avg_sales)
        / NULLIF(previous_avg_sales, 0),
        2
    ) AS sales_change_pct,

    ROUND(
        100.0 * (recent_avg_customers - previous_avg_customers)
        / NULLIF(previous_avg_customers, 0),
        2
    ) AS customers_change_pct

FROM period_metrics

WHERE previous_open_days >= 30
  AND recent_open_days >= 30

ORDER BY sales_change_pct ASC

LIMIT 15;

-- ============================================================
-- 2.2 Peer-Adjusted Performance Changes
-- ============================================================

-- Compare recent store performance with other stores
-- of the same Store Type and Assortment.
-- Exclude the store itself from its peer benchmark.

WITH reference_date AS (
    SELECT
        MAX(d.full_date) AS last_date
    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
),

period_metrics AS (
    SELECT
        f.store_id,
        s.store_type,
        s.assortment,

        -- Previous 8 weeks
        SUM(CASE
            WHEN d.full_date <= DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            ) THEN 1 ELSE 0
        END) AS previous_open_days,

        AVG(CASE
            WHEN d.full_date <= DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            ) THEN f.sales
        END) AS previous_avg_sales,

        AVG(CASE
            WHEN d.full_date <= DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            ) THEN f.customers
        END) AS previous_avg_customers,

        -- Recent 8 weeks
        SUM(CASE
            WHEN d.full_date > DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            ) THEN 1 ELSE 0
        END) AS recent_open_days,

        AVG(CASE
            WHEN d.full_date > DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            ) THEN f.sales
        END) AS recent_avg_sales,

        AVG(CASE
            WHEN d.full_date > DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            ) THEN f.customers
        END) AS recent_avg_customers

    FROM fact_daily_sales f

    JOIN dim_store s
        ON f.store_id = s.store_id

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN reference_date r

    WHERE f.open = 1
      AND d.full_date > DATE_SUB(
          r.last_date, INTERVAL 112 DAY
      )
      AND d.full_date <= r.last_date

    GROUP BY
        f.store_id,
        s.store_type,
        s.assortment
),

-- Calculate changes for stores with sufficient observations

store_changes AS (
    SELECT
        store_id,
        store_type,
        assortment,
        previous_open_days,
        recent_open_days,

        100.0 * (
            recent_avg_sales - previous_avg_sales
        ) / NULLIF(previous_avg_sales, 0)
            AS sales_change_pct,

        100.0 * (
            recent_avg_customers - previous_avg_customers
        ) / NULLIF(previous_avg_customers, 0)
            AS customers_change_pct

    FROM period_metrics

    WHERE previous_open_days >= 30
      AND recent_open_days >= 30
      AND previous_avg_sales > 0
      AND previous_avg_customers > 0
),

-- Calculate average peer changes, excluding each store

peer_comparison AS (
    SELECT
        *,

        COUNT(*) OVER (
            PARTITION BY store_type, assortment
        ) - 1 AS peer_store_count,

        (
            SUM(sales_change_pct) OVER (
                PARTITION BY store_type, assortment
            ) - sales_change_pct
        )
        / NULLIF(
            COUNT(*) OVER (
                PARTITION BY store_type, assortment
            ) - 1, 0
        ) AS peer_sales_change_pct,

        (
            SUM(customers_change_pct) OVER (
                PARTITION BY store_type, assortment
            ) - customers_change_pct
        )
        / NULLIF(
            COUNT(*) OVER (
                PARTITION BY store_type, assortment
            ) - 1, 0
        ) AS peer_customers_change_pct

    FROM store_changes
)

-- Final comparison

SELECT
    store_id,
    store_type,
    assortment,
    peer_store_count,

    ROUND(sales_change_pct, 2)
        AS sales_change_pct,

    ROUND(peer_sales_change_pct, 2)
        AS peer_sales_change_pct,

    ROUND(
        sales_change_pct - peer_sales_change_pct,
        2
    ) AS sales_vs_peers_pp,

    ROUND(customers_change_pct, 2)
        AS customers_change_pct,

    ROUND(peer_customers_change_pct, 2)
        AS peer_customers_change_pct,

    ROUND(
        customers_change_pct - peer_customers_change_pct,
        2
    ) AS customers_vs_peers_pp

FROM peer_comparison

-- Require at least 5 other comparable stores.
WHERE peer_store_count >= 5

ORDER BY sales_vs_peers_pp ASC

LIMIT 15;

-- ============================================================
-- 2.3 Historical Peer Performance
-- ============================================================

-- Compare historical average daily sales with other stores
-- of the same Store Type and Assortment.
-- Exclude each store from its own peer benchmark.

WITH peer_metrics AS (
    SELECT
        store_id,
        store_type,
        assortment,
        open_days,
        avg_daily_sales,

        COUNT(*) OVER (
            PARTITION BY store_type, assortment
        ) AS group_store_count,

        SUM(avg_daily_sales) OVER (
            PARTITION BY store_type, assortment
        ) AS group_sales_sum

    FROM vw_store_performance
),

peer_comparison AS (
    SELECT
        store_id,
        store_type,
        assortment,
        open_days,
        avg_daily_sales,

        group_store_count - 1 AS peer_store_count,

        (
            group_sales_sum - avg_daily_sales
        ) / NULLIF(group_store_count - 1, 0)
            AS peer_avg_daily_sales

    FROM peer_metrics
)

SELECT
    store_id,
    store_type,
    assortment,
    open_days,
    peer_store_count,

    ROUND(avg_daily_sales, 2)
        AS avg_daily_sales,

    ROUND(peer_avg_daily_sales, 2)
        AS peer_avg_daily_sales,

    ROUND(
        100.0 * (
            avg_daily_sales - peer_avg_daily_sales
        ) / NULLIF(peer_avg_daily_sales, 0),
        2
    ) AS historical_peer_gap_pct

FROM peer_comparison

WHERE peer_store_count >= 5

ORDER BY historical_peer_gap_pct ASC

LIMIT 15;

-- ============================================================
-- 2.4 Historical Performance of Recently Declining Stores
-- ============================================================

-- Investigate whether stores with significant recent declines
-- also underperform against their historical peer benchmarks.

WITH peer_metrics AS (
    SELECT
        store_id,
        store_type,
        assortment,
        avg_daily_sales,

        COUNT(*) OVER (
            PARTITION BY store_type, assortment
        ) AS group_store_count,

        SUM(avg_daily_sales) OVER (
            PARTITION BY store_type, assortment
        ) AS group_sales_sum

    FROM vw_store_performance
),

peer_comparison AS (
    SELECT
        store_id,
        store_type,
        assortment,
        avg_daily_sales,

        group_store_count - 1 AS peer_store_count,

        (
            group_sales_sum - avg_daily_sales
        ) / NULLIF(group_store_count - 1, 0)
            AS peer_avg_daily_sales

    FROM peer_metrics
)

SELECT
    store_id,
    store_type,
    assortment,
    peer_store_count,

    ROUND(avg_daily_sales, 2)
        AS avg_daily_sales,

    ROUND(peer_avg_daily_sales, 2)
        AS peer_avg_daily_sales,

    ROUND(
        100.0 * (
            avg_daily_sales - peer_avg_daily_sales
        ) / NULLIF(peer_avg_daily_sales, 0),
        2
    ) AS historical_peer_gap_pct

FROM peer_comparison

WHERE store_id IN (39, 722, 657, 550, 711, 971)
  AND peer_store_count >= 5

ORDER BY historical_peer_gap_pct ASC;


-- ============================================================
-- 2.5 INTEGRATED STORE MONITORING
-- ============================================================

-- Objective:
-- Integrate historical store performance, recent sales
-- changes, and peer-adjusted performance indicators.
--
-- Business rules:
-- - Compare the latest 8 weeks with the previous 8 weeks.
-- - Minimum 20 operating days per period.
-- - Peer groups: Store Type + Assortment.
-- - Minimum 5 stores per peer group, including the
--   evaluated store.
-- - Exclude each store from its own peer benchmark.
--
-- ============================================================


CREATE OR REPLACE VIEW vw_store_monitoring AS

WITH reference_date AS (
    SELECT
        MAX(d.full_date) AS last_date

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key
),

-- ============================================================
-- 1. RECENT AND PREVIOUS PERIOD METRICS
-- ============================================================

period_metrics AS (
    SELECT
        f.store_id,

        -- Previous 8 weeks

        SUM(CASE
            WHEN d.full_date <= DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            )
            THEN 1 ELSE 0
        END) AS previous_open_days,

        -- Recent 8 weeks

        SUM(CASE
            WHEN d.full_date > DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            )
            THEN 1 ELSE 0
        END) AS recent_open_days,

        -- Previous average sales

        AVG(CASE
            WHEN d.full_date <= DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            )
            THEN f.sales
        END) AS previous_avg_sales,

        -- Recent average sales

        AVG(CASE
            WHEN d.full_date > DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            )
            THEN f.sales
        END) AS recent_avg_sales,

        -- Previous average customers

        AVG(CASE
            WHEN d.full_date <= DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            )
            THEN f.customers
        END) AS previous_avg_customers,

        -- Recent average customers

        AVG(CASE
            WHEN d.full_date > DATE_SUB(
                r.last_date, INTERVAL 56 DAY
            )
            THEN f.customers
        END) AS recent_avg_customers

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN reference_date r

    WHERE f.open = 1

      AND d.full_date > DATE_SUB(
          r.last_date, INTERVAL 112 DAY
      )

      AND d.full_date <= r.last_date

    GROUP BY f.store_id
),

-- ============================================================
-- 2. CALCULATE RECENT PERFORMANCE CHANGES
-- ============================================================

store_changes AS (
    SELECT
        store_id,
        previous_open_days,
        recent_open_days,

        100.0 * (
            recent_avg_sales - previous_avg_sales
        )
        / NULLIF(previous_avg_sales, 0)
            AS sales_change_pct,

        100.0 * (
            recent_avg_customers - previous_avg_customers
        )
        / NULLIF(previous_avg_customers, 0)
            AS customers_change_pct

    FROM period_metrics

    -- Minimum 20 operating days per period

    WHERE previous_open_days >= 20
      AND recent_open_days >= 20

      AND previous_avg_sales > 0
      AND previous_avg_customers > 0
),

-- ============================================================
-- 3. HISTORICAL PEER PERFORMANCE
-- ============================================================

historical_peers AS (
    SELECT
        store_id,

        COUNT(*) OVER (
            PARTITION BY store_type, assortment
        ) - 1 AS historical_peer_count,

        (
            SUM(avg_daily_sales) OVER (
                PARTITION BY store_type, assortment
            ) - avg_daily_sales
        )
        / NULLIF(
            COUNT(*) OVER (
                PARTITION BY store_type, assortment
            ) - 1, 0
        ) AS peer_avg_daily_sales

    FROM vw_store_performance
),

-- ============================================================
-- 4. RECENT PEER PERFORMANCE CHANGES
-- ============================================================

recent_peers AS (
    SELECT
        c.store_id,

        COUNT(*) OVER (
            PARTITION BY p.store_type, p.assortment
        ) - 1 AS recent_peer_count,

        (
            SUM(c.sales_change_pct) OVER (
                PARTITION BY p.store_type, p.assortment
            ) - c.sales_change_pct
        )
        / NULLIF(
            COUNT(*) OVER (
                PARTITION BY p.store_type, p.assortment
            ) - 1, 0
        ) AS peer_sales_change_pct,

        (
            SUM(c.customers_change_pct) OVER (
                PARTITION BY p.store_type, p.assortment
            ) - c.customers_change_pct
        )
        / NULLIF(
            COUNT(*) OVER (
                PARTITION BY p.store_type, p.assortment
            ) - 1, 0
        ) AS peer_customers_change_pct

    FROM store_changes c

    JOIN vw_store_performance p
        ON c.store_id = p.store_id
)

-- ============================================================
-- 5. FINAL INTEGRATED MONITORING VIEW
-- ============================================================

SELECT
    p.store_id,
    p.store_type,
    p.assortment,

    -- Historical store metrics

    p.open_days,
    p.avg_daily_sales,
    p.avg_daily_customers,
    p.sales_per_customer,

    -- Historical peer performance

    h.historical_peer_count,

    CASE
        WHEN h.historical_peer_count >= 4
        THEN 100.0 * (
            p.avg_daily_sales - h.peer_avg_daily_sales
        ) / NULLIF(h.peer_avg_daily_sales, 0)
    END AS historical_peer_gap_pct,

    -- Recent store performance

    c.previous_open_days,
    c.recent_open_days,
    c.sales_change_pct,
    c.customers_change_pct,

    -- Recent peer performance

    r.recent_peer_count,

    CASE
        WHEN r.recent_peer_count >= 4
        THEN c.sales_change_pct - r.peer_sales_change_pct
    END AS sales_vs_peers_pp,

    CASE
        WHEN r.recent_peer_count >= 4
        THEN c.customers_change_pct
             - r.peer_customers_change_pct
    END AS customers_vs_peers_pp

FROM vw_store_performance p

LEFT JOIN historical_peers h
    ON p.store_id = h.store_id

LEFT JOIN store_changes c
    ON p.store_id = c.store_id

LEFT JOIN recent_peers r
    ON p.store_id = r.store_id;


-- ============================================================
-- 2.6 VALIDATE INTEGRATED MONITORING VIEW
-- ============================================================

-- Check view coverage and missing metrics

SELECT
    COUNT(*) AS total_stores,

    COUNT(DISTINCT store_id) AS unique_stores,

    SUM(
        CASE
            WHEN sales_vs_peers_pp IS NULL
            THEN 1 ELSE 0
        END
    ) AS stores_without_recent_peer_comparison

FROM vw_store_monitoring;


-- ============================================================
-- 2.7 VALIDATE MONITORING METRICS
-- ============================================================

SELECT
    store_id,

    ROUND(historical_peer_gap_pct, 2)
        AS historical_peer_gap_pct,

    ROUND(sales_change_pct, 2)
        AS sales_change_pct,

    ROUND(sales_vs_peers_pp, 2)
        AS sales_vs_peers_pp,

    ROUND(customers_change_pct, 2)
        AS customers_change_pct,

    ROUND(customers_vs_peers_pp, 2)
        AS customers_vs_peers_pp

FROM vw_store_monitoring

WHERE store_id IN (39, 550, 657, 711, 971, 722)

ORDER BY store_id;
