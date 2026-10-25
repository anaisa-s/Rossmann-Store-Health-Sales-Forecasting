
-- ============================================================
-- ROSSMANN STORE HEALTH — EARLY WARNING ANALYSIS
-- ============================================================

USE rossmann;

-- ============================================================
-- Q1. PEER PERFORMANCE GAP DISTRIBUTION
-- ============================================================
-- Objective:
-- Analyse the distribution of store performance relative
-- to comparable stores.
--
-- Peer groups are defined by Store Type and Assortment.
-- Each store is excluded from its own peer benchmark.
--
-- Only peer groups containing at least 5 stores are included.
-- Stores are divided into 10 performance deciles.
--
-- Decile 1: Lowest relative performance (bottom 10%)
-- Decile 10: Highest relative performance (top 10%)
--
-- Results will help establish data-driven thresholds
-- for the Early Warning System.
-- ============================================================


-- 1. Calculate average sales per operating day

WITH store_performance AS (
    SELECT
        f.store_id,
        s.store_type,
        s.assortment,
        COUNT(*) AS open_days,
        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f

    JOIN dim_store s
        ON f.store_id = s.store_id

    WHERE f.open = 1

    GROUP BY
        f.store_id,
        s.store_type,
        s.assortment
),


-- 2. Calculate peer group statistics

peer_stats AS (
    SELECT
        *,

        COUNT(*) OVER (
            PARTITION BY store_type, assortment
        ) AS peer_group_size,

        SUM(avg_daily_sales) OVER (
            PARTITION BY store_type, assortment
        ) AS peer_sales_sum

    FROM store_performance
),


-- 3. Calculate peer average excluding the evaluated store

peer_comparison AS (
    SELECT
        store_id,
        store_type,
        assortment,
        open_days,
        avg_daily_sales,
        peer_group_size,

        (peer_sales_sum - avg_daily_sales)
        / NULLIF(peer_group_size - 1, 0)
            AS peer_avg_sales

    FROM peer_stats

    WHERE peer_group_size >= 5
),


-- 4. Calculate percentage gap from peer benchmark

performance_gaps AS (
    SELECT
        store_id,
        store_type,
        assortment,
        avg_daily_sales,
        peer_avg_sales,

        100.0 * (
            avg_daily_sales - peer_avg_sales
        )
        / NULLIF(peer_avg_sales, 0)
            AS peer_gap_pct

    FROM peer_comparison
),


-- 5. Rank stores into performance deciles

ranked_stores AS (
    SELECT
        *,

        NTILE(10) OVER (
            ORDER BY peer_gap_pct
        ) AS performance_decile

    FROM performance_gaps

    WHERE peer_gap_pct IS NOT NULL
)


-- 6. Summarise performance distribution

SELECT
    performance_decile,

    COUNT(*) AS store_count,

    ROUND(
        MIN(peer_gap_pct), 2
    ) AS min_gap_pct,

    ROUND(
        AVG(peer_gap_pct), 2
    ) AS avg_gap_pct,

    ROUND(
        MAX(peer_gap_pct), 2
    ) AS max_gap_pct

FROM ranked_stores

GROUP BY performance_decile

ORDER BY performance_decile;


-- ============================================================
-- Q2. RECENT SALES CHANGE DISTRIBUTION
-- ============================================================
-- Objective:
-- Analyse changes in average daily sales between the
-- latest 8 weeks and the previous 8 weeks.
--
-- Only operating days are considered.
-- Each store must have at least 20 open days per period.
--
-- Stores are divided into 10 deciles:
-- Decile 1 = Largest sales declines
-- Decile 10 = Largest sales increases
-- ============================================================

WITH max_date AS (
    SELECT
        MAX(d.full_date) AS latest_date
    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
),

period_performance AS (
    SELECT
        f.store_id,

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS recent_open_days,

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS previous_open_days,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS recent_avg_sales,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS previous_avg_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN max_date m

    WHERE f.open = 1
      AND d.full_date >
          DATE_SUB(m.latest_date, INTERVAL 16 WEEK)

    GROUP BY f.store_id
),

sales_changes AS (
    SELECT
        store_id,

        100.0 *
        (recent_avg_sales - previous_avg_sales)
        / NULLIF(previous_avg_sales, 0)
            AS sales_change_pct

    FROM period_performance

    WHERE recent_open_days >= 20
      AND previous_open_days >= 20
),

ranked_stores AS (
    SELECT
        store_id,
        sales_change_pct,

        NTILE(10) OVER (
            ORDER BY sales_change_pct, store_id
        ) AS sales_change_decile

    FROM sales_changes

    WHERE sales_change_pct IS NOT NULL
)

SELECT
    sales_change_decile,

    COUNT(*) AS store_count,

    ROUND(MIN(sales_change_pct), 2)
        AS min_change_pct,

    ROUND(AVG(sales_change_pct), 2)
        AS avg_change_pct,

    ROUND(MAX(sales_change_pct), 2)
        AS max_change_pct

FROM ranked_stores

GROUP BY sales_change_decile

ORDER BY sales_change_decile;



-- ============================================================
-- Q3. CONSECUTIVE MONTHLY SALES DECLINES
-- ============================================================
-- Objective:
-- Identify stores experiencing persistent monthly declines
-- in average sales per operating day.
--
-- Compare the last 4 complete calendar months.
-- Each month must contain at least 15 operating days.
--
-- Classification:
-- 0 = No decline in the latest month
-- 1 = One consecutive monthly decline
-- 2 = Two consecutive monthly declines
-- 3 = Three consecutive monthly declines
--
-- ============================================================

-- 1. Identify the latest available date

WITH max_date AS (
    SELECT
        MAX(d.full_date) AS latest_date

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key
),

-- 2. Identify the latest complete month

reference_month AS (
    SELECT
        CASE
            WHEN latest_date = LAST_DAY(latest_date)
                THEN CAST(
                    DATE_FORMAT(latest_date, '%Y-%m-01')
                    AS DATE
                )

            ELSE CAST(
                DATE_FORMAT(
                    DATE_SUB(latest_date, INTERVAL 1 MONTH),
                    '%Y-%m-01'
                ) AS DATE
            )

        END AS ref_month_start

    FROM max_date
),

-- 3. Calculate monthly average sales per operating day

monthly_performance AS (
    SELECT
        f.store_id,

        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        ) AS month_start,

        COUNT(*) AS open_days,

        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN reference_month r

    WHERE f.open = 1

      AND d.full_date >=
          DATE_SUB(r.ref_month_start, INTERVAL 3 MONTH)

      AND d.full_date <
          DATE_ADD(r.ref_month_start, INTERVAL 1 MONTH)

    GROUP BY
        f.store_id,
        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        )

    HAVING COUNT(*) >= 15
),

-- 4. Compare the last 4 months

monthly_comparison AS (
    SELECT
        m.store_id,

        MAX(
            CASE
                WHEN m.month_start = r.ref_month_start
                THEN m.avg_daily_sales
            END
        ) AS m0,

        MAX(
            CASE
                WHEN m.month_start =
                    DATE_SUB(r.ref_month_start, INTERVAL 1 MONTH)
                THEN m.avg_daily_sales
            END
        ) AS m1,

        MAX(
            CASE
                WHEN m.month_start =
                    DATE_SUB(r.ref_month_start, INTERVAL 2 MONTH)
                THEN m.avg_daily_sales
            END
        ) AS m2,

        MAX(
            CASE
                WHEN m.month_start =
                    DATE_SUB(r.ref_month_start, INTERVAL 3 MONTH)
                THEN m.avg_daily_sales
            END
        ) AS m3

    FROM monthly_performance m

    CROSS JOIN reference_month r

    GROUP BY m.store_id
),

-- 5. Identify consecutive monthly declines

decline_streaks AS (
    SELECT
        store_id,

        CASE
            WHEN m0 < m1
             AND m1 < m2
             AND m2 < m3
                THEN 3

            WHEN m0 < m1
             AND m1 < m2
                THEN 2

            WHEN m0 < m1
                THEN 1

            ELSE 0

        END AS consecutive_declines,

        100.0 * (m0 - m3)
        / NULLIF(m3, 0)
            AS change_3_months_pct

    FROM monthly_comparison

    WHERE m0 IS NOT NULL
      AND m1 IS NOT NULL
      AND m2 IS NOT NULL
      AND m3 IS NOT NULL
),

-- 6. Summarise decline patterns

decline_summary AS (
    SELECT
        consecutive_declines,

        COUNT(*) AS store_count,

        ROUND(
            AVG(change_3_months_pct), 2
        ) AS avg_change_3_months_pct

    FROM decline_streaks

    GROUP BY consecutive_declines
)

-- 7. Final results

SELECT
    consecutive_declines,

    store_count,

    ROUND(
        100.0 * store_count
        / SUM(store_count) OVER (), 2
    ) AS pct_of_stores,

    avg_change_3_months_pct

FROM decline_summary

ORDER BY consecutive_declines;


-- ============================================================
-- Q4. COMBINED EARLY WARNING SIGNALS
-- ============================================================
-- Objective:
-- Identify stores showing multiple performance warning
-- signals simultaneously.
--
-- Signals:
-- 1. Peer Performance Gap <= -25.70%
-- 2. Recent Sales Change <= -9.08%
-- 3. Three consecutive monthly sales declines
--
-- Thresholds are preliminary and require validation.
-- This analysis does not assign final health statuses.
-- ============================================================


WITH

-- ============================================================
-- 1. REFERENCE DATES
-- ============================================================

max_date AS (
    SELECT MAX(d.full_date) AS latest_date
    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
),

reference_month AS (
    SELECT
        CASE
            WHEN latest_date = LAST_DAY(latest_date)
            THEN CAST(
                DATE_FORMAT(latest_date, '%Y-%m-01')
                AS DATE
            )
            ELSE CAST(
                DATE_FORMAT(
                    DATE_SUB(latest_date, INTERVAL 1 MONTH),
                    '%Y-%m-01'
                ) AS DATE
            )
        END AS ref_month_start
    FROM max_date
),

-- ============================================================
-- 2. PEER PERFORMANCE GAP
-- ============================================================

store_performance AS (
    SELECT
        f.store_id,
        s.store_type,
        s.assortment,
        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f
    JOIN dim_store s
        ON f.store_id = s.store_id

    WHERE f.open = 1

    GROUP BY
        f.store_id,
        s.store_type,
        s.assortment
),

peer_stats AS (
    SELECT
        *,
        COUNT(*) OVER (
            PARTITION BY store_type, assortment
        ) AS peer_group_size,

        SUM(avg_daily_sales) OVER (
            PARTITION BY store_type, assortment
        ) AS peer_sales_sum

    FROM store_performance
),

peer_gaps AS (
    SELECT
        store_id,
        store_type,
        assortment,

        100.0 * (
            avg_daily_sales -
            (peer_sales_sum - avg_daily_sales)
            / NULLIF(peer_group_size - 1, 0)
        )
        / NULLIF(
            (peer_sales_sum - avg_daily_sales)
            / NULLIF(peer_group_size - 1, 0),
            0
        ) AS peer_gap_pct

    FROM peer_stats
    WHERE peer_group_size >= 5
),

-- ============================================================
-- 3. RECENT SALES CHANGE
-- ============================================================

recent_periods AS (
    SELECT
        f.store_id,

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS recent_open_days,

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS previous_open_days,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS recent_avg_sales,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS previous_avg_sales

    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
    CROSS JOIN max_date m

    WHERE f.open = 1
      AND d.full_date >
          DATE_SUB(m.latest_date, INTERVAL 16 WEEK)

    GROUP BY f.store_id
),

recent_changes AS (
    SELECT
        store_id,

        100.0 * (
            recent_avg_sales - previous_avg_sales
        )
        / NULLIF(previous_avg_sales, 0)
            AS sales_change_pct

    FROM recent_periods

    WHERE recent_open_days >= 20
      AND previous_open_days >= 20
),

-- ============================================================
-- 4. CONSECUTIVE MONTHLY DECLINES
-- ============================================================

monthly_performance AS (
    SELECT
        f.store_id,

        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        ) AS month_start,

        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
    CROSS JOIN reference_month r

    WHERE f.open = 1
      AND d.full_date >=
          DATE_SUB(r.ref_month_start, INTERVAL 3 MONTH)
      AND d.full_date <
          DATE_ADD(r.ref_month_start, INTERVAL 1 MONTH)

    GROUP BY
        f.store_id,
        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        )

    HAVING COUNT(*) >= 15
),

monthly_comparison AS (
    SELECT
        m.store_id,

        MAX(CASE
            WHEN m.month_start = r.ref_month_start
            THEN m.avg_daily_sales
        END) AS m0,

        MAX(CASE
            WHEN m.month_start =
                DATE_SUB(r.ref_month_start, INTERVAL 1 MONTH)
            THEN m.avg_daily_sales
        END) AS m1,

        MAX(CASE
            WHEN m.month_start =
                DATE_SUB(r.ref_month_start, INTERVAL 2 MONTH)
            THEN m.avg_daily_sales
        END) AS m2,

        MAX(CASE
            WHEN m.month_start =
                DATE_SUB(r.ref_month_start, INTERVAL 3 MONTH)
            THEN m.avg_daily_sales
        END) AS m3

    FROM monthly_performance m
    CROSS JOIN reference_month r

    GROUP BY m.store_id
),

decline_streaks AS (
    SELECT
        store_id,

        CASE
            WHEN m0 < m1
             AND m1 < m2
             AND m2 < m3 THEN 3

            WHEN m0 < m1
             AND m1 < m2 THEN 2

            WHEN m0 < m1 THEN 1

            ELSE 0
        END AS consecutive_declines

    FROM monthly_comparison

    WHERE m0 IS NOT NULL
      AND m1 IS NOT NULL
      AND m2 IS NOT NULL
      AND m3 IS NOT NULL
),

-- ============================================================
-- 5. COMBINE THREE INDICATORS
-- ============================================================

combined_indicators AS (
    SELECT
        p.store_id,
        p.store_type,
        p.assortment,
        p.peer_gap_pct,
        r.sales_change_pct,
        d.consecutive_declines

    FROM peer_gaps p

    INNER JOIN recent_changes r
        ON p.store_id = r.store_id

    INNER JOIN decline_streaks d
        ON p.store_id = d.store_id

    WHERE p.peer_gap_pct IS NOT NULL
      AND r.sales_change_pct IS NOT NULL
),

-- ============================================================
-- 6. CREATE WARNING FLAGS
-- ============================================================

warning_flags AS (
    SELECT
        store_id,
        store_type,
        assortment,

        CASE
            WHEN peer_gap_pct <= -25.70 THEN 1
            ELSE 0
        END AS peer_gap_flag,

        CASE
            WHEN sales_change_pct <= -9.08 THEN 1
            ELSE 0
        END AS sales_decline_flag,

        CASE
            WHEN consecutive_declines = 3 THEN 1
            ELSE 0
        END AS persistent_decline_flag

    FROM combined_indicators
),

-- ============================================================
-- 7. COUNT COMBINED WARNING SIGNALS
-- ============================================================

signal_counts AS (
    SELECT
        *,
        (
            peer_gap_flag +
            sales_decline_flag +
            persistent_decline_flag
        ) AS total_warning_signals

    FROM warning_flags
)

-- ============================================================
-- 8. FINAL SUMMARY
-- ============================================================

SELECT
    total_warning_signals,

    peer_gap_flag,
    sales_decline_flag,
    persistent_decline_flag,

    COUNT(*) AS store_count,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS pct_of_stores

FROM signal_counts

GROUP BY
    total_warning_signals,
    peer_gap_flag,
    sales_decline_flag,
    persistent_decline_flag

ORDER BY
    total_warning_signals DESC,
    store_count DESC;


-- ============================================================
-- Q5. HISTORICAL VALIDATION OF EARLY WARNING SIGNALS
-- ============================================================
-- Objective:
-- Evaluate whether warning signals observed at a past
-- date are associated with subsequent sales deterioration.
--
-- Historical evaluation dates:
-- 2014-09-30, 2014-12-31, 2015-03-31
--
-- Future outcome:
-- Sales decline >= 10% during the next 8 weeks,
-- compared with the previous 8 weeks.
--
-- Important:
-- Future sales are used ONLY to evaluate outcomes.
-- They are not used to generate warning signals.
-- ============================================================


WITH

-- 1. Historical evaluation dates

cutoffs AS (
    SELECT DATE('2014-09-30') AS cutoff_date
    UNION ALL
    SELECT DATE('2014-12-31')
    UNION ALL
    SELECT DATE('2015-03-31')
),

-- 2. Historical store performance

historical_sales AS (
    SELECT
        c.cutoff_date,
        f.store_id,
        s.store_type,
        s.assortment,
        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    JOIN dim_store s
        ON f.store_id = s.store_id

    CROSS JOIN cutoffs c

    WHERE f.open = 1
      AND d.full_date <= c.cutoff_date

    GROUP BY
        c.cutoff_date,
        f.store_id,
        s.store_type,
        s.assortment
),

-- 3. Historical peer group statistics

peer_stats AS (
    SELECT
        *,

        COUNT(*) OVER (
            PARTITION BY
                cutoff_date,
                store_type,
                assortment
        ) AS peer_group_size,

        SUM(avg_daily_sales) OVER (
            PARTITION BY
                cutoff_date,
                store_type,
                assortment
        ) AS peer_sales_sum

    FROM historical_sales
),

-- 4. Peer benchmark excluding the evaluated store

peer_averages AS (
    SELECT
        cutoff_date,
        store_id,
        avg_daily_sales,

        (peer_sales_sum - avg_daily_sales)
        / NULLIF(peer_group_size - 1, 0)
            AS peer_avg_sales

    FROM peer_stats
    WHERE peer_group_size >= 5
),

peer_gaps AS (
    SELECT
        cutoff_date,
        store_id,

        100.0 * (
            avg_daily_sales - peer_avg_sales
        )
        / NULLIF(peer_avg_sales, 0)
            AS peer_gap_pct

    FROM peer_averages
),

-- 5. Previous, recent and future sales periods

period_performance AS (
    SELECT
        c.cutoff_date,
        f.store_id,

        -- Previous 8 weeks

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS previous_open_days,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS previous_avg_sales,

        -- Recent 8 weeks

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
             AND d.full_date <= c.cutoff_date
            THEN 1
        END) AS recent_open_days,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
             AND d.full_date <= c.cutoff_date
            THEN f.sales
        END) AS recent_avg_sales,

        -- Future 8 weeks (evaluation only)

        COUNT(CASE
            WHEN d.full_date > c.cutoff_date
             AND d.full_date <=
                DATE_ADD(c.cutoff_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS future_open_days,

        AVG(CASE
            WHEN d.full_date > c.cutoff_date
             AND d.full_date <=
                DATE_ADD(c.cutoff_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS future_avg_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN cutoffs c

    WHERE f.open = 1
      AND d.full_date >
          DATE_SUB(c.cutoff_date, INTERVAL 16 WEEK)
      AND d.full_date <=
          DATE_ADD(c.cutoff_date, INTERVAL 8 WEEK)

    GROUP BY
        c.cutoff_date,
        f.store_id
),

-- 6. Monthly historical performance

monthly_performance AS (
    SELECT
        c.cutoff_date,
        f.store_id,

        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        ) AS month_start,

        COUNT(*) AS open_days,

        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN cutoffs c

    WHERE f.open = 1
      AND d.full_date >= DATE_SUB(
          CAST(
              DATE_FORMAT(c.cutoff_date, '%Y-%m-01')
              AS DATE
          ),
          INTERVAL 3 MONTH
      )
      AND d.full_date <= c.cutoff_date

    GROUP BY
        c.cutoff_date,
        f.store_id,
        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        )

    HAVING COUNT(*) >= 15
),

-- 7. Compare four complete months

monthly_comparison AS (
    SELECT
        cutoff_date,
        store_id,

        MAX(CASE
            WHEN month_start =
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                )
            THEN avg_daily_sales
        END) AS m0,

        MAX(CASE
            WHEN month_start = DATE_SUB(
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                ),
                INTERVAL 1 MONTH
            )
            THEN avg_daily_sales
        END) AS m1,

        MAX(CASE
            WHEN month_start = DATE_SUB(
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                ),
                INTERVAL 2 MONTH
            )
            THEN avg_daily_sales
        END) AS m2,

        MAX(CASE
            WHEN month_start = DATE_SUB(
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                ),
                INTERVAL 3 MONTH
            )
            THEN avg_daily_sales
        END) AS m3

    FROM monthly_performance

    GROUP BY
        cutoff_date,
        store_id
),

-- 8. Calculate the three historical warning flags

warning_flags AS (
    SELECT
        p.cutoff_date,
        p.store_id,

        CASE
            WHEN g.peer_gap_pct <= -25.70
            THEN 1 ELSE 0
        END AS peer_gap_flag,

        CASE
            WHEN 100.0 * (
                p.recent_avg_sales -
                p.previous_avg_sales
            ) / NULLIF(p.previous_avg_sales, 0)
                <= -9.08
            THEN 1 ELSE 0
        END AS sales_decline_flag,

        CASE
            WHEN m.m0 < m.m1
             AND m.m1 < m.m2
             AND m.m2 < m.m3
            THEN 1 ELSE 0
        END AS persistent_decline_flag,

        100.0 * (
            p.future_avg_sales -
            p.recent_avg_sales
        )
        / NULLIF(p.recent_avg_sales, 0)
            AS future_change_pct

    FROM period_performance p

    JOIN peer_gaps g
        ON p.cutoff_date = g.cutoff_date
       AND p.store_id = g.store_id

    JOIN monthly_comparison m
        ON p.cutoff_date = m.cutoff_date
       AND p.store_id = m.store_id

    WHERE p.previous_open_days >= 20
      AND p.recent_open_days >= 20
      AND p.future_open_days >= 20

      AND p.previous_avg_sales > 0
      AND p.recent_avg_sales > 0
      AND p.future_avg_sales IS NOT NULL

      AND g.peer_gap_pct IS NOT NULL

      AND m.m0 IS NOT NULL
      AND m.m1 IS NOT NULL
      AND m.m2 IS NOT NULL
      AND m.m3 IS NOT NULL
),

-- 9. Calculate signals and future outcome

evaluation AS (
    SELECT
        cutoff_date,
        store_id,

        (
            peer_gap_flag +
            sales_decline_flag +
            persistent_decline_flag
        ) AS total_warning_signals,

        future_change_pct,

        CASE
            WHEN future_change_pct <= -10
            THEN 1 ELSE 0
        END AS future_decline_flag

    FROM warning_flags
)

-- 10. Evaluate subsequent deterioration

SELECT
    total_warning_signals,

    COUNT(*) AS store_evaluations,

    ROUND(
        AVG(future_change_pct), 2
    ) AS avg_future_change_pct,

    SUM(future_decline_flag)
        AS future_decline_count,

    ROUND(
        100.0 * AVG(future_decline_flag), 2
    ) AS future_decline_rate_pct

FROM evaluation

GROUP BY total_warning_signals

ORDER BY total_warning_signals;


-- ============================================================
-- Q5A. HISTORICAL VALIDATION BY EVALUATION DATE
-- ============================================================
-- Objective:
-- Evaluate whether historical warning signals are associated
-- with subsequent sales deterioration.
--
-- Evaluation dates:
-- 2014-09-30
-- 2014-12-31
-- 2015-03-31
--
-- Future outcome:
-- Sales decline of at least 10% during the following 8 weeks,
-- compared with the preceding 8 weeks.
--
-- Results are grouped by evaluation date and number of signals.
--
-- Important:
-- Future sales are used only to evaluate outcomes.
-- They are not used to generate warning signals.
-- ============================================================


WITH

-- ============================================================
-- 1. HISTORICAL EVALUATION DATES
-- ============================================================

cutoffs AS (
    SELECT DATE('2014-09-30') AS cutoff_date
    UNION ALL
    SELECT DATE('2014-12-31')
    UNION ALL
    SELECT DATE('2015-03-31')
),

-- ============================================================
-- 2. HISTORICAL STORE PERFORMANCE
-- ============================================================

historical_sales AS (
    SELECT
        c.cutoff_date,
        f.store_id,
        s.store_type,
        s.assortment,
        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    JOIN dim_store s
        ON f.store_id = s.store_id

    CROSS JOIN cutoffs c

    WHERE f.open = 1
      AND d.full_date <= c.cutoff_date

    GROUP BY
        c.cutoff_date,
        f.store_id,
        s.store_type,
        s.assortment
),

-- ============================================================
-- 3. HISTORICAL PEER GROUP STATISTICS
-- ============================================================

peer_stats AS (
    SELECT
        *,

        COUNT(*) OVER (
            PARTITION BY
                cutoff_date,
                store_type,
                assortment
        ) AS peer_group_size,

        SUM(avg_daily_sales) OVER (
            PARTITION BY
                cutoff_date,
                store_type,
                assortment
        ) AS peer_sales_sum

    FROM historical_sales
),

-- ============================================================
-- 4. PEER PERFORMANCE GAP
-- ============================================================

peer_averages AS (
    SELECT
        cutoff_date,
        store_id,
        avg_daily_sales,

        (peer_sales_sum - avg_daily_sales)
        / NULLIF(peer_group_size - 1, 0)
            AS peer_avg_sales

    FROM peer_stats

    WHERE peer_group_size >= 5
),

peer_gaps AS (
    SELECT
        cutoff_date,
        store_id,

        100.0 * (
            avg_daily_sales - peer_avg_sales
        )
        / NULLIF(peer_avg_sales, 0)
            AS peer_gap_pct

    FROM peer_averages
),

-- ============================================================
-- 5. PREVIOUS, RECENT AND FUTURE SALES
-- ============================================================

period_performance AS (
    SELECT
        c.cutoff_date,
        f.store_id,

        -- Previous 8 weeks

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS previous_open_days,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS previous_avg_sales,

        -- Recent 8 weeks

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
             AND d.full_date <= c.cutoff_date
            THEN 1
        END) AS recent_open_days,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
             AND d.full_date <= c.cutoff_date
            THEN f.sales
        END) AS recent_avg_sales,

        -- Future 8 weeks (evaluation only)

        COUNT(CASE
            WHEN d.full_date > c.cutoff_date
             AND d.full_date <=
                DATE_ADD(c.cutoff_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS future_open_days,

        AVG(CASE
            WHEN d.full_date > c.cutoff_date
             AND d.full_date <=
                DATE_ADD(c.cutoff_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS future_avg_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN cutoffs c

    WHERE f.open = 1

      AND d.full_date >
          DATE_SUB(c.cutoff_date, INTERVAL 16 WEEK)

      AND d.full_date <=
          DATE_ADD(c.cutoff_date, INTERVAL 8 WEEK)

    GROUP BY
        c.cutoff_date,
        f.store_id
),

-- ============================================================
-- 6. MONTHLY HISTORICAL PERFORMANCE
-- ============================================================

monthly_performance AS (
    SELECT
        c.cutoff_date,
        f.store_id,

        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        ) AS month_start,

        COUNT(*) AS open_days,

        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN cutoffs c

    WHERE f.open = 1

      AND d.full_date >= DATE_SUB(
          CAST(
              DATE_FORMAT(c.cutoff_date, '%Y-%m-01')
              AS DATE
          ),
          INTERVAL 3 MONTH
      )

      AND d.full_date <= c.cutoff_date

    GROUP BY
        c.cutoff_date,
        f.store_id,
        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        )

    HAVING COUNT(*) >= 15
),

-- ============================================================
-- 7. COMPARE FOUR COMPLETE MONTHS
-- ============================================================

monthly_comparison AS (
    SELECT
        cutoff_date,
        store_id,

        -- Latest month

        MAX(CASE
            WHEN month_start =
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                )
            THEN avg_daily_sales
        END) AS m0,

        -- Previous month

        MAX(CASE
            WHEN month_start = DATE_SUB(
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                ),
                INTERVAL 1 MONTH
            )
            THEN avg_daily_sales
        END) AS m1,

        -- Two months ago

        MAX(CASE
            WHEN month_start = DATE_SUB(
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                ),
                INTERVAL 2 MONTH
            )
            THEN avg_daily_sales
        END) AS m2,

        -- Three months ago

        MAX(CASE
            WHEN month_start = DATE_SUB(
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                ),
                INTERVAL 3 MONTH
            )
            THEN avg_daily_sales
        END) AS m3

    FROM monthly_performance

    GROUP BY
        cutoff_date,
        store_id
),

-- ============================================================
-- 8. CREATE HISTORICAL WARNING FLAGS
-- ============================================================

warning_flags AS (
    SELECT
        p.cutoff_date,
        p.store_id,

        -- Signal 1: Low peer performance

        CASE
            WHEN g.peer_gap_pct <= -25.70
            THEN 1
            ELSE 0
        END AS peer_gap_flag,

        -- Signal 2: Large recent sales decline

        CASE
            WHEN 100.0 * (
                p.recent_avg_sales -
                p.previous_avg_sales
            ) / NULLIF(p.previous_avg_sales, 0)
                <= -9.08
            THEN 1
            ELSE 0
        END AS sales_decline_flag,

        -- Signal 3: Persistent monthly decline

        CASE
            WHEN m.m0 < m.m1
             AND m.m1 < m.m2
             AND m.m2 < m.m3
            THEN 1
            ELSE 0
        END AS persistent_decline_flag,

        -- Future performance (evaluation only)

        100.0 * (
            p.future_avg_sales -
            p.recent_avg_sales
        )
        / NULLIF(p.recent_avg_sales, 0)
            AS future_change_pct

    FROM period_performance p

    JOIN peer_gaps g
        ON p.cutoff_date = g.cutoff_date
       AND p.store_id = g.store_id

    JOIN monthly_comparison m
        ON p.cutoff_date = m.cutoff_date
       AND p.store_id = m.store_id

    WHERE p.previous_open_days >= 20
      AND p.recent_open_days >= 20
      AND p.future_open_days >= 20

      AND p.previous_avg_sales > 0
      AND p.recent_avg_sales > 0
      AND p.future_avg_sales IS NOT NULL

      AND g.peer_gap_pct IS NOT NULL

      AND m.m0 IS NOT NULL
      AND m.m1 IS NOT NULL
      AND m.m2 IS NOT NULL
      AND m.m3 IS NOT NULL
),

-- ============================================================
-- 9. CALCULATE SIGNALS AND FUTURE OUTCOME
-- ============================================================

evaluation AS (
    SELECT
        cutoff_date,
        store_id,

        (
            peer_gap_flag +
            sales_decline_flag +
            persistent_decline_flag
        ) AS total_warning_signals,

        future_change_pct,

        CASE
            WHEN future_change_pct <= -10
            THEN 1
            ELSE 0
        END AS future_decline_flag

    FROM warning_flags
)

-- ============================================================
-- 10. FINAL RESULTS BY HISTORICAL EVALUATION DATE
-- ============================================================

SELECT
    cutoff_date,

    total_warning_signals,

    COUNT(*) AS store_evaluations,

    ROUND(
        AVG(future_change_pct), 2
    ) AS avg_future_change_pct,

    SUM(future_decline_flag)
        AS future_decline_count,

    ROUND(
        100.0 * AVG(future_decline_flag), 2
    ) AS future_decline_rate_pct

FROM evaluation

GROUP BY
    cutoff_date,
    total_warning_signals

ORDER BY
    cutoff_date,
    total_warning_signals;


-- ============================================================
-- Q6. PEER-ADJUSTED FUTURE SALES PERFORMANCE
-- ============================================================
-- Objective:
-- Evaluate whether historical warning signals identify
-- stores that subsequently underperform their peers.
--
-- Historical evaluation dates:
-- 2014-09-30, 2014-12-31, 2015-03-31
--
-- Warning signals:
-- 1. Peer Performance Gap <= -25.70%
-- 2. Recent Sales Change <= -9.08%
-- 3. Three consecutive monthly declines
--
-- Future outcome:
-- Store future sales change at least 10 percentage points
-- below the future change of comparable stores.
--
-- Future information is used only for evaluation.
-- ============================================================

USE rossmann;

WITH

-- 1. HISTORICAL EVALUATION DATES

cutoffs AS (
    SELECT DATE('2014-09-30') AS cutoff_date
    UNION ALL
    SELECT DATE('2014-12-31')
    UNION ALL
    SELECT DATE('2015-03-31')
),

-- 2. HISTORICAL STORE PERFORMANCE

historical_sales AS (
    SELECT
        c.cutoff_date,
        f.store_id,
        s.store_type,
        s.assortment,
        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    JOIN dim_store s
        ON f.store_id = s.store_id

    CROSS JOIN cutoffs c

    WHERE f.open = 1
      AND d.full_date <= c.cutoff_date

    GROUP BY
        c.cutoff_date,
        f.store_id,
        s.store_type,
        s.assortment
),

-- 3. HISTORICAL PEER BENCHMARK

historical_peer_stats AS (
    SELECT
        *,

        COUNT(*) OVER (
            PARTITION BY
                cutoff_date, store_type, assortment
        ) AS peer_group_size,

        SUM(avg_daily_sales) OVER (
            PARTITION BY
                cutoff_date, store_type, assortment
        ) AS peer_sales_sum

    FROM historical_sales
),

historical_peer_gaps AS (
    SELECT
        cutoff_date,
        store_id,

        100.0 * (
            avg_daily_sales -
            (peer_sales_sum - avg_daily_sales)
            / NULLIF(peer_group_size - 1, 0)
        )
        / NULLIF(
            (peer_sales_sum - avg_daily_sales)
            / NULLIF(peer_group_size - 1, 0),
            0
        ) AS peer_gap_pct

    FROM historical_peer_stats

    WHERE peer_group_size >= 5
),

-- 4. SALES PERIODS

period_performance AS (
    SELECT
        c.cutoff_date,
        f.store_id,

        -- Previous 8 weeks

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS previous_open_days,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 16 WEEK)
             AND d.full_date <=
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS previous_avg_sales,

        -- Recent 8 weeks

        COUNT(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
             AND d.full_date <= c.cutoff_date
            THEN 1
        END) AS recent_open_days,

        AVG(CASE
            WHEN d.full_date >
                DATE_SUB(c.cutoff_date, INTERVAL 8 WEEK)
             AND d.full_date <= c.cutoff_date
            THEN f.sales
        END) AS recent_avg_sales,

        -- Future 8 weeks

        COUNT(CASE
            WHEN d.full_date > c.cutoff_date
             AND d.full_date <=
                DATE_ADD(c.cutoff_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS future_open_days,

        AVG(CASE
            WHEN d.full_date > c.cutoff_date
             AND d.full_date <=
                DATE_ADD(c.cutoff_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS future_avg_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN cutoffs c

    WHERE f.open = 1
      AND d.full_date >
          DATE_SUB(c.cutoff_date, INTERVAL 16 WEEK)
      AND d.full_date <=
          DATE_ADD(c.cutoff_date, INTERVAL 8 WEEK)

    GROUP BY
        c.cutoff_date,
        f.store_id
),

-- 5. REQUIRE SUFFICIENT OBSERVATIONS

eligible_periods AS (
    SELECT *
    FROM period_performance

    WHERE previous_open_days >= 20
      AND recent_open_days >= 20
      AND future_open_days >= 20

      AND previous_avg_sales > 0
      AND recent_avg_sales > 0
      AND future_avg_sales IS NOT NULL
),

-- 6. FUTURE PEER GROUP STATISTICS
-- Used only to evaluate future performance.

future_peer_stats AS (
    SELECT
        e.*,
        s.store_type,
        s.assortment,

        COUNT(*) OVER (
            PARTITION BY
                e.cutoff_date,
                s.store_type,
                s.assortment
        ) AS peer_group_size,

        SUM(e.recent_avg_sales) OVER (
            PARTITION BY
                e.cutoff_date,
                s.store_type,
                s.assortment
        ) AS peer_recent_sales_sum,

        SUM(e.future_avg_sales) OVER (
            PARTITION BY
                e.cutoff_date,
                s.store_type,
                s.assortment
        ) AS peer_future_sales_sum

    FROM eligible_periods e

    JOIN dim_store s
        ON e.store_id = s.store_id
),

-- 7. FUTURE STORE AND PEER SALES CHANGES

future_comparison AS (
    SELECT
        cutoff_date,
        store_id,
        previous_avg_sales,
        recent_avg_sales,
        future_avg_sales,

        100.0 * (
            future_avg_sales - recent_avg_sales
        ) / NULLIF(recent_avg_sales, 0)
            AS store_future_change_pct,

        100.0 * (
            (peer_future_sales_sum - future_avg_sales)
            -
            (peer_recent_sales_sum - recent_avg_sales)
        )
        / NULLIF(
            peer_recent_sales_sum - recent_avg_sales,
            0
        ) AS peer_future_change_pct

    FROM future_peer_stats

    WHERE peer_group_size >= 5
),

-- 8. HISTORICAL MONTHLY PERFORMANCE

monthly_performance AS (
    SELECT
        c.cutoff_date,
        f.store_id,

        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        ) AS month_start,

        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f

    JOIN dim_date d
        ON f.date_key = d.date_key

    CROSS JOIN cutoffs c

    WHERE f.open = 1

      AND d.full_date >= DATE_SUB(
          CAST(
              DATE_FORMAT(c.cutoff_date, '%Y-%m-01')
              AS DATE
          ),
          INTERVAL 3 MONTH
      )

      AND d.full_date <= c.cutoff_date

    GROUP BY
        c.cutoff_date,
        f.store_id,
        CAST(
            DATE_FORMAT(d.full_date, '%Y-%m-01')
            AS DATE
        )

    HAVING COUNT(*) >= 15
),

-- 9. COMPARE FOUR MONTHS

monthly_comparison AS (
    SELECT
        cutoff_date,
        store_id,

        MAX(CASE
            WHEN month_start = CAST(
                DATE_FORMAT(cutoff_date, '%Y-%m-01')
                AS DATE
            )
            THEN avg_daily_sales
        END) AS m0,

        MAX(CASE
            WHEN month_start = DATE_SUB(
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                ),
                INTERVAL 1 MONTH
            )
            THEN avg_daily_sales
        END) AS m1,

        MAX(CASE
            WHEN month_start = DATE_SUB(
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                ),
                INTERVAL 2 MONTH
            )
            THEN avg_daily_sales
        END) AS m2,

        MAX(CASE
            WHEN month_start = DATE_SUB(
                CAST(
                    DATE_FORMAT(cutoff_date, '%Y-%m-01')
                    AS DATE
                ),
                INTERVAL 3 MONTH
            )
            THEN avg_daily_sales
        END) AS m3

    FROM monthly_performance

    GROUP BY
        cutoff_date,
        store_id
),

-- 10. CREATE HISTORICAL WARNING FLAGS

warning_flags AS (
    SELECT
        f.cutoff_date,
        f.store_id,

        CASE
            WHEN g.peer_gap_pct <= -25.70
            THEN 1 ELSE 0
        END AS peer_gap_flag,

        CASE
            WHEN 100.0 * (
                f.recent_avg_sales -
                f.previous_avg_sales
            ) / NULLIF(f.previous_avg_sales, 0)
                <= -9.08
            THEN 1 ELSE 0
        END AS sales_decline_flag,

        CASE
            WHEN m.m0 < m.m1
             AND m.m1 < m.m2
             AND m.m2 < m.m3
            THEN 1 ELSE 0
        END AS persistent_decline_flag,

        f.store_future_change_pct,
        f.peer_future_change_pct

    FROM future_comparison f

    JOIN historical_peer_gaps g
        ON f.cutoff_date = g.cutoff_date
       AND f.store_id = g.store_id

    JOIN monthly_comparison m
        ON f.cutoff_date = m.cutoff_date
       AND f.store_id = m.store_id

    WHERE g.peer_gap_pct IS NOT NULL
      AND f.peer_future_change_pct IS NOT NULL

      AND m.m0 IS NOT NULL
      AND m.m1 IS NOT NULL
      AND m.m2 IS NOT NULL
      AND m.m3 IS NOT NULL
),

-- 11. CALCULATE PEER-ADJUSTED FUTURE PERFORMANCE

evaluation AS (
    SELECT
        cutoff_date,
        store_id,

        (
            peer_gap_flag +
            sales_decline_flag +
            persistent_decline_flag
        ) AS total_warning_signals,

        store_future_change_pct,
        peer_future_change_pct,

        (
            store_future_change_pct -
            peer_future_change_pct
        ) AS peer_adjusted_change_pp

    FROM warning_flags
),

-- 12. DEFINE FUTURE RELATIVE DETERIORATION

final_evaluation AS (
    SELECT
        *,

        CASE
            WHEN peer_adjusted_change_pp <= -10
            THEN 1 ELSE 0
        END AS future_relative_decline_flag

    FROM evaluation
)

-- 13. FINAL RESULTS

SELECT
    cutoff_date,
    total_warning_signals,

    COUNT(*) AS store_evaluations,

    ROUND(
        AVG(store_future_change_pct), 2
    ) AS avg_store_future_change_pct,

    ROUND(
        AVG(peer_future_change_pct), 2
    ) AS avg_peer_future_change_pct,

    ROUND(
        AVG(peer_adjusted_change_pp), 2
    ) AS avg_peer_adjusted_change_pp,

    SUM(future_relative_decline_flag)
        AS future_relative_decline_count,

    ROUND(
        100.0 * AVG(future_relative_decline_flag),
        2
    ) AS future_relative_decline_rate_pct

FROM final_evaluation

GROUP BY
    cutoff_date,
    total_warning_signals

ORDER BY
    cutoff_date,
    total_warning_signals;

