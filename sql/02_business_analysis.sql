
/*
ROSSMANN STORE PERFORMANCE ANALYSIS
*/

USE rossmann;

 -- ============================================================
-- Q1. Which stores have the highest and lowest average daily sales?
-- ============================================================

-- Stores have different numbers of operating days, so average sales
-- per open day provides a fairer comparison of store performance.


-- Top 10 stores by average daily sales

SELECT
    store_id,
    COUNT(*) AS open_days,
    SUM(sales) AS total_sales,
    ROUND(AVG(sales), 2) AS avg_daily_sales
FROM fact_daily_sales
WHERE open = 1
GROUP BY store_id
ORDER BY avg_daily_sales DESC
LIMIT 10;


-- Bottom 10 stores by average daily sales

SELECT
    store_id,
    COUNT(*) AS open_days,
    SUM(sales) AS total_sales,
    ROUND(AVG(sales), 2) AS avg_daily_sales
FROM fact_daily_sales
WHERE open = 1
GROUP BY store_id
ORDER BY avg_daily_sales ASC
LIMIT 10;


-- ============================================================
-- Q2. Which stores attract the highest and lowest average
--     number of customers per day?
-- ============================================================

-- Stores have different numbers of operating days, so average customers
-- per open day provides a fairer comparison of customer traffic.


-- Top 10 stores by average daily customers

SELECT
    store_id,
    COUNT(*) AS open_days,
    SUM(customers) AS total_customers,
    ROUND(AVG(customers), 0) AS avg_daily_customers
FROM fact_daily_sales
WHERE open = 1
GROUP BY store_id
ORDER BY avg_daily_customers DESC
LIMIT 10;


-- Bottom 10 stores by average daily customers

SELECT
    store_id,
    COUNT(*) AS open_days,
    SUM(customers) AS total_customers,
    ROUND(AVG(customers), 0) AS avg_daily_customers
FROM fact_daily_sales
WHERE open = 1
GROUP BY store_id
ORDER BY avg_daily_customers ASC
LIMIT 10;

-- ============================================================
-- Q3. Which stores have the highest and lowest sales per customer?
-- ============================================================

-- Sales per customer measures how much sales revenue is generated
-- per customer visit, helping distinguish high traffic from higher
-- customer spending.


-- Top 10 stores by sales per customer

SELECT
    store_id,
    SUM(sales) AS total_sales,
    SUM(customers) AS total_customers,
    ROUND(
        SUM(sales) / NULLIF(SUM(customers), 0),
        2
    ) AS sales_per_customer
FROM fact_daily_sales
WHERE open = 1
GROUP BY store_id
HAVING SUM(customers) > 0
ORDER BY sales_per_customer DESC
LIMIT 10;


-- Bottom 10 stores by sales per customer

SELECT
    store_id,
    SUM(sales) AS total_sales,
    SUM(customers) AS total_customers,
    ROUND(
        SUM(sales) / NULLIF(SUM(customers), 0),
        2
    ) AS sales_per_customer
FROM fact_daily_sales
WHERE open = 1
GROUP BY store_id
HAVING SUM(customers) > 0
ORDER BY sales_per_customer ASC
LIMIT 10;

-- ============================================================
-- Q4. Which stores are growing and which are showing
--     a sustained decline in sales?
-- ============================================================

-- Identify stores with 3 consecutive monthly increases
-- or decreases in average sales per open day.
-- Only months with at least 15 operating days are included.

WITH monthly_performance AS (
    SELECT
        f.store_id,
        CAST(DATE_FORMAT(d.full_date, '%Y-%m-01') AS DATE)
            AS month_start,
        COUNT(*) AS open_days,
        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key

    WHERE f.open = 1

    GROUP BY f.store_id, month_start
    HAVING COUNT(*) >= 15
),

monthly_history AS (
    SELECT
        store_id,
        month_start,
        avg_daily_sales,

        LAG(month_start, 3) OVER (
            PARTITION BY store_id
            ORDER BY month_start
        ) AS month_3_ago,

        LAG(avg_daily_sales, 1) OVER (
            PARTITION BY store_id
            ORDER BY month_start
        ) AS prev_1,

        LAG(avg_daily_sales, 2) OVER (
            PARTITION BY store_id
            ORDER BY month_start
        ) AS prev_2,

        LAG(avg_daily_sales, 3) OVER (
            PARTITION BY store_id
            ORDER BY month_start
        ) AS prev_3

    FROM monthly_performance
),

store_trends AS (
    SELECT
        store_id,
        month_start,
        avg_daily_sales,

        ROUND(
            100.0 * (avg_daily_sales - prev_3)
            / NULLIF(prev_3, 0),
            2
        ) AS change_3_months_pct,

        CASE
            WHEN TIMESTAMPDIFF(
                MONTH, month_3_ago, month_start
            ) = 3
            AND avg_daily_sales > prev_1
            AND prev_1 > prev_2
            AND prev_2 > prev_3
                THEN 'Sustained growth'

            WHEN TIMESTAMPDIFF(
                MONTH, month_3_ago, month_start
            ) = 3
            AND avg_daily_sales < prev_1
            AND prev_1 < prev_2
            AND prev_2 < prev_3
                THEN 'Sustained decline'

            ELSE 'Other'
        END AS sales_trend

    FROM monthly_history
),

ranked_stores AS (
    SELECT
        store_id,
        sales_trend,
        ROUND(avg_daily_sales, 2) AS avg_daily_sales,
        change_3_months_pct,

        ROW_NUMBER() OVER (
            PARTITION BY sales_trend
            ORDER BY
                CASE WHEN sales_trend = 'Sustained decline'
                    THEN change_3_months_pct END ASC,
                CASE WHEN sales_trend = 'Sustained growth'
                    THEN change_3_months_pct END DESC
        ) AS store_rank

    FROM store_trends
    WHERE month_start = (
        SELECT MAX(month_start)
        FROM monthly_performance
    )
    AND sales_trend IN (
        'Sustained growth',
        'Sustained decline'
    )
)

SELECT
    store_id,
    sales_trend,
    avg_daily_sales,
    change_3_months_pct
FROM ranked_stores
WHERE store_rank <= 10
ORDER BY
    FIELD(sales_trend, 'Sustained decline', 'Sustained growth'),
    store_rank;

-- ============================================================
-- Q5. Which stores are underperforming compared with similar
--     stores of the same store type and assortment?
-- ============================================================

-- Stores are benchmarked against peers with the same store type
-- and assortment. Average daily sales are used to control for
-- differences in the number of operating days.

WITH store_performance AS (
    SELECT
        f.store_id,
        s.store_type,
        s.assortment,
        COUNT(*) AS open_days,
        ROUND(AVG(f.sales), 2) AS avg_daily_sales
    FROM fact_daily_sales f
    JOIN dim_store s
        ON f.store_id = s.store_id
    WHERE f.open = 1
    GROUP BY
        f.store_id,
        s.store_type,
        s.assortment
),

peer_benchmark AS (
    SELECT
        store_id,
        store_type,
        assortment,
        open_days,
        avg_daily_sales,

        ROUND(
            AVG(avg_daily_sales) OVER (
                PARTITION BY store_type, assortment
            ),
            2
        ) AS peer_avg_daily_sales,

        COUNT(*) OVER (
            PARTITION BY store_type, assortment
        ) AS peer_group_size

    FROM store_performance
)

SELECT
    store_id,
    store_type,
    assortment,
    open_days,
    avg_daily_sales,
    peer_avg_daily_sales,
    peer_group_size,

    ROUND(
        avg_daily_sales - peer_avg_daily_sales,
        2
    ) AS difference_from_peer_avg,

    ROUND(
        100.0 * (avg_daily_sales - peer_avg_daily_sales)
        / NULLIF(peer_avg_daily_sales, 0),
        2
    ) AS performance_vs_peer_pct

FROM peer_benchmark

WHERE avg_daily_sales < peer_avg_daily_sales

ORDER BY performance_vs_peer_pct ASC;

-- ============================================================
-- Q6. Which stores have experienced the largest recent declines
--     in sales, customers, or sales per customer?
-- ============================================================

-- Compare the latest 8 weeks with the previous 8 weeks.
-- Only operating days are included.
-- Return the 10 largest declines for each performance metric.

WITH max_date AS (
    SELECT
        MAX(full_date) AS latest_date
    FROM dim_date
),

period_performance AS (
    SELECT
        f.store_id,

        -- Open days
        COUNT(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS recent_open_days,

        COUNT(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
             AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN 1
        END) AS previous_open_days,

        -- Average daily sales
        AVG(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS recent_avg_daily_sales,

        AVG(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
             AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS previous_avg_daily_sales,

        -- Average daily customers
        AVG(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.customers
        END) AS recent_avg_daily_customers,

        AVG(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
             AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.customers
        END) AS previous_avg_daily_customers,

        -- Sales per customer: recent period
        SUM(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END)
        /
        NULLIF(
            SUM(CASE
                WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                THEN f.customers
            END), 0
        ) AS recent_sales_per_customer,

        -- Sales per customer: previous period
        SUM(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
             AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END)
        /
        NULLIF(
            SUM(CASE
                WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
                 AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                THEN f.customers
            END), 0
        ) AS previous_sales_per_customer

    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
    CROSS JOIN max_date m

    WHERE f.open = 1
      AND d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)

    GROUP BY f.store_id
),

changes AS (
    SELECT
        *,

        100.0 *
        (recent_avg_daily_sales - previous_avg_daily_sales)
        / NULLIF(previous_avg_daily_sales, 0)
            AS sales_change_pct,

        100.0 *
        (recent_avg_daily_customers - previous_avg_daily_customers)
        / NULLIF(previous_avg_daily_customers, 0)
            AS customers_change_pct,

        100.0 *
        (recent_sales_per_customer - previous_sales_per_customer)
        / NULLIF(previous_sales_per_customer, 0)
            AS sales_per_customer_change_pct

    FROM period_performance
),

metric_declines AS (

    -- Sales declines
    SELECT
        store_id,
        'Sales' AS metric,
        previous_open_days,
        recent_open_days,
        previous_avg_daily_sales AS previous_value,
        recent_avg_daily_sales AS recent_value,
        sales_change_pct AS change_pct
    FROM changes
    WHERE sales_change_pct < 0

    UNION ALL

    -- Customer traffic declines
    SELECT
        store_id,
        'Customers',
        previous_open_days,
        recent_open_days,
        previous_avg_daily_customers,
        recent_avg_daily_customers,
        customers_change_pct
    FROM changes
    WHERE customers_change_pct < 0

    UNION ALL

    -- Sales per customer declines
    SELECT
        store_id,
        'Sales per customer',
        previous_open_days,
        recent_open_days,
        previous_sales_per_customer,
        recent_sales_per_customer,
        sales_per_customer_change_pct
    FROM changes
    WHERE sales_per_customer_change_pct < 0
),

ranked_declines AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY metric
            ORDER BY change_pct ASC, store_id
        ) AS metric_rank
    FROM metric_declines
)

SELECT
    metric,
    metric_rank,
    store_id,
    previous_open_days,
    recent_open_days,
    ROUND(previous_value, 2) AS previous_value,
    ROUND(recent_value, 2) AS recent_value,
    ROUND(change_pct, 2) AS change_pct

FROM ranked_declines

WHERE metric_rank <= 10

ORDER BY
    FIELD(metric, 'Sales', 'Customers', 'Sales per customer'),
    metric_rank;

-- ============================================================
-- Q7. Which stores show unusually volatile or inconsistent
--     sales performance?
-- ============================================================

-- Monthly average daily sales are used to reduce daily noise.
-- Volatility is measured using the coefficient of variation (CV),
-- which allows stores with different sales levels to be compared.
-- Stores in the highest 10% of CV are flagged as unusually volatile.

WITH monthly_performance AS (
    SELECT
        f.store_id,
        d.year,
        d.month,
        AVG(f.sales) AS avg_daily_sales
    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
    WHERE f.open = 1
    GROUP BY
        f.store_id,
        d.year,
        d.month
),

store_volatility AS (
    SELECT
        store_id,
        COUNT(*) AS months_observed,
        AVG(avg_daily_sales) AS avg_daily_sales,
        STDDEV_POP(avg_daily_sales) AS sales_stddev,

        100.0 * STDDEV_POP(avg_daily_sales)
        / NULLIF(AVG(avg_daily_sales), 0)
            AS coefficient_of_variation

    FROM monthly_performance
    GROUP BY store_id
),

volatility_ranking AS (
    SELECT
        *,
        NTILE(10) OVER (
            ORDER BY coefficient_of_variation
        ) AS volatility_decile
    FROM store_volatility
)

SELECT
    store_id,
    months_observed,
    ROUND(avg_daily_sales, 2) AS avg_daily_sales,
    ROUND(sales_stddev, 2) AS sales_stddev,
    ROUND(coefficient_of_variation, 2)
        AS coefficient_of_variation_pct
FROM volatility_ranking
WHERE volatility_decile = 10
ORDER BY coefficient_of_variation DESC;

-- ============================================================
-- Q8. Is store underperformance mainly driven by declining
--     customer traffic or lower spending per customer?
-- ============================================================

-- Stores with declining average daily sales are analysed to determine
-- whether the deterioration is mainly associated with lower customer
-- traffic, lower sales per customer, or both.

WITH max_date AS (
    SELECT
        MAX(full_date) AS latest_date
    FROM dim_date
),

period_performance AS (
    SELECT
        f.store_id,

        -- Average daily sales: recent 8 weeks
        SUM(
            CASE
                WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                THEN f.sales
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS recent_avg_daily_sales,

        -- Average daily sales: previous 8 weeks
        SUM(
            CASE
                WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
                 AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                THEN f.sales
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
                     AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS previous_avg_daily_sales,


        -- Average daily customers: recent 8 weeks
        SUM(
            CASE
                WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                THEN f.customers
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS recent_avg_daily_customers,

        -- Average daily customers: previous 8 weeks
        SUM(
            CASE
                WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
                 AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                THEN f.customers
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
                     AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS previous_avg_daily_customers,


        -- Sales per customer: recent 8 weeks
        SUM(
            CASE
                WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                THEN f.sales
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                    THEN f.customers
                END
            ),
            0
        ) AS recent_sales_per_customer,

        -- Sales per customer: previous 8 weeks
        SUM(
            CASE
                WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
                 AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                THEN f.sales
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)
                     AND d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
                    THEN f.customers
                END
            ),
            0
        ) AS previous_sales_per_customer

    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
    CROSS JOIN max_date m

    WHERE
        f.open = 1
        AND d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)

    GROUP BY f.store_id
),

changes AS (
    SELECT
        *,

        100.0 *
        (recent_avg_daily_sales - previous_avg_daily_sales)
        / NULLIF(previous_avg_daily_sales, 0)
            AS sales_change_pct,

        100.0 *
        (recent_avg_daily_customers - previous_avg_daily_customers)
        / NULLIF(previous_avg_daily_customers, 0)
            AS customer_change_pct,

        100.0 *
        (recent_sales_per_customer - previous_sales_per_customer)
        / NULLIF(previous_sales_per_customer, 0)
            AS sales_per_customer_change_pct

    FROM period_performance
)

SELECT
    store_id,

    ROUND(sales_change_pct, 2) AS sales_change_pct,
    ROUND(customer_change_pct, 2) AS customer_change_pct,
    ROUND(sales_per_customer_change_pct, 2)
        AS sales_per_customer_change_pct,

    CASE

        WHEN customer_change_pct < 0
             AND sales_per_customer_change_pct >= 0
            THEN 'Customer traffic'

        WHEN customer_change_pct >= 0
             AND sales_per_customer_change_pct < 0
            THEN 'Sales per customer'

        WHEN customer_change_pct < 0
             AND sales_per_customer_change_pct < 0
             AND ABS(customer_change_pct)
                 > ABS(sales_per_customer_change_pct)
            THEN 'Mainly customer traffic'

        WHEN customer_change_pct < 0
             AND sales_per_customer_change_pct < 0
             AND ABS(sales_per_customer_change_pct)
                 > ABS(customer_change_pct)
            THEN 'Mainly sales per customer'

        WHEN customer_change_pct < 0
             AND sales_per_customer_change_pct < 0
            THEN 'Both'

        ELSE 'Other'

    END AS main_contributing_component

FROM changes

WHERE sales_change_pct < 0

ORDER BY sales_change_pct ASC;


-- ============================================================
-- Q8. Summary of main contributing components
-- ============================================================

-- Compare the latest 8 weeks with the previous 8 weeks.
-- Identify the main component associated with declining sales.

WITH max_date AS (
    SELECT
        MAX(full_date) AS latest_date
    FROM dim_date
),

period_performance AS (
    SELECT
        f.store_id,

        -- Average daily sales
        AVG(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS recent_avg_daily_sales,

        AVG(CASE
            WHEN d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END) AS previous_avg_daily_sales,

        -- Average daily customers
        AVG(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.customers
        END) AS recent_avg_daily_customers,

        AVG(CASE
            WHEN d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.customers
        END) AS previous_avg_daily_customers,

        -- Sales per customer: recent period
        SUM(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END)
        /
        NULLIF(SUM(CASE
            WHEN d.full_date > DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.customers
        END), 0) AS recent_sales_per_customer,

        -- Sales per customer: previous period
        SUM(CASE
            WHEN d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.sales
        END)
        /
        NULLIF(SUM(CASE
            WHEN d.full_date <= DATE_SUB(m.latest_date, INTERVAL 8 WEEK)
            THEN f.customers
        END), 0) AS previous_sales_per_customer

    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
    CROSS JOIN max_date m

    WHERE f.open = 1
      AND d.full_date > DATE_SUB(m.latest_date, INTERVAL 16 WEEK)

    GROUP BY f.store_id
),

changes AS (
    SELECT
        store_id,

        100.0 *
        (recent_avg_daily_sales - previous_avg_daily_sales)
        / NULLIF(previous_avg_daily_sales, 0)
            AS sales_change_pct,

        100.0 *
        (recent_avg_daily_customers - previous_avg_daily_customers)
        / NULLIF(previous_avg_daily_customers, 0)
            AS customer_change_pct,

        100.0 *
        (recent_sales_per_customer - previous_sales_per_customer)
        / NULLIF(previous_sales_per_customer, 0)
            AS sales_per_customer_change_pct

    FROM period_performance
),

classified_stores AS (
    SELECT
        store_id,

        CASE
            WHEN customer_change_pct < 0
                 AND sales_per_customer_change_pct >= 0
                THEN 'Customer traffic'

            WHEN customer_change_pct >= 0
                 AND sales_per_customer_change_pct < 0
                THEN 'Sales per customer'

            WHEN customer_change_pct < 0
                 AND sales_per_customer_change_pct < 0
                 AND ABS(customer_change_pct)
                     > ABS(sales_per_customer_change_pct)
                THEN 'Mainly customer traffic'

            WHEN customer_change_pct < 0
                 AND sales_per_customer_change_pct < 0
                 AND ABS(sales_per_customer_change_pct)
                     > ABS(customer_change_pct)
                THEN 'Mainly sales per customer'

            WHEN customer_change_pct < 0
                 AND sales_per_customer_change_pct < 0
                THEN 'Both'

            ELSE 'Other'

        END AS main_contributing_component

    FROM changes
    WHERE sales_change_pct < 0
)

SELECT
    main_contributing_component,
    COUNT(*) AS store_count,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_stores

FROM classified_stores
GROUP BY main_contributing_component
ORDER BY store_count DESC;

-- ============================================================
-- Q9. How much do promotions increase sales and customer
--     traffic across stores?
-- ============================================================

-- Compare average daily sales and customers between promotional
-- and non-promotional days. Only operating days are included.


-- ============================================================
-- 1. STORE-LEVEL PROMOTIONAL PERFORMANCE
-- ============================================================

WITH promo_performance AS (
    SELECT
        store_id,

        SUM(CASE WHEN promo = 1 THEN 1 ELSE 0 END)
            AS promo_days,

        SUM(CASE WHEN promo = 0 THEN 1 ELSE 0 END)
            AS non_promo_days,

        AVG(CASE WHEN promo = 1 THEN sales END)
            AS promo_avg_sales,

        AVG(CASE WHEN promo = 0 THEN sales END)
            AS non_promo_avg_sales,

        AVG(CASE WHEN promo = 1 THEN customers END)
            AS promo_avg_customers,

        AVG(CASE WHEN promo = 0 THEN customers END)
            AS non_promo_avg_customers

    FROM fact_daily_sales
    WHERE open = 1
    GROUP BY store_id

    HAVING promo_days >= 20
       AND non_promo_days >= 20
)

SELECT
    store_id,
    promo_days,
    non_promo_days,

    ROUND(promo_avg_sales, 2) AS promo_avg_sales,
    ROUND(non_promo_avg_sales, 2) AS non_promo_avg_sales,

    ROUND(
        100.0 * (promo_avg_sales - non_promo_avg_sales)
        / NULLIF(non_promo_avg_sales, 0),
        2
    ) AS sales_uplift_pct,

    ROUND(promo_avg_customers, 0) AS promo_avg_customers,
    ROUND(non_promo_avg_customers, 0) AS non_promo_avg_customers,

    ROUND(
        100.0 * (promo_avg_customers - non_promo_avg_customers)
        / NULLIF(non_promo_avg_customers, 0),
        2
    ) AS customers_uplift_pct

FROM promo_performance
ORDER BY sales_uplift_pct DESC;


-- ============================================================
-- 2. OVERALL PROMOTIONAL PERFORMANCE
-- ============================================================

WITH promo_performance AS (
    SELECT
        promo,
        COUNT(*) AS store_days,
        AVG(sales) AS avg_daily_sales,
        AVG(customers) AS avg_daily_customers
    FROM fact_daily_sales
    WHERE open = 1
    GROUP BY promo
)

SELECT
    MAX(CASE WHEN promo = 1 THEN store_days END)
        AS promo_store_days,

    MAX(CASE WHEN promo = 0 THEN store_days END)
        AS non_promo_store_days,

    ROUND(MAX(CASE WHEN promo = 1 THEN avg_daily_sales END), 2)
        AS promo_avg_sales,

    ROUND(MAX(CASE WHEN promo = 0 THEN avg_daily_sales END), 2)
        AS non_promo_avg_sales,

    ROUND(
        100.0 * (
            MAX(CASE WHEN promo = 1 THEN avg_daily_sales END) -
            MAX(CASE WHEN promo = 0 THEN avg_daily_sales END)
        )
        / NULLIF(
            MAX(CASE WHEN promo = 0 THEN avg_daily_sales END), 0
        ),
        2
    ) AS sales_uplift_pct,

    ROUND(MAX(CASE WHEN promo = 1 THEN avg_daily_customers END), 0)
        AS promo_avg_customers,

    ROUND(MAX(CASE WHEN promo = 0 THEN avg_daily_customers END), 0)
        AS non_promo_avg_customers,

    ROUND(
        100.0 * (
            MAX(CASE WHEN promo = 1 THEN avg_daily_customers END) -
            MAX(CASE WHEN promo = 0 THEN avg_daily_customers END)
        )
        / NULLIF(
            MAX(CASE WHEN promo = 0 THEN avg_daily_customers END), 0
        ),
        2
    ) AS customers_uplift_pct

FROM promo_performance;

-- ============================================================
-- Q10. Which stores are highly dependent on promotions,
--      and which stores show weak promotional uplift?
-- ============================================================

-- Promotion dependence is assessed by comparing the share
-- of sales generated during promotions with the share of
-- operating days that had promotions.
-- Promotional uplift compares average daily sales with and
-- without promotions.

WITH promo_performance AS (
    SELECT
        store_id,

        SUM(promo = 1) AS promo_days,
        SUM(promo = 0) AS non_promo_days,

        SUM(CASE WHEN promo = 1 THEN sales ELSE 0 END)
            AS promo_sales,

        SUM(sales) AS total_sales,

        AVG(CASE WHEN promo = 1 THEN sales END)
            AS promo_avg_sales,

        AVG(CASE WHEN promo = 0 THEN sales END)
            AS non_promo_avg_sales

    FROM fact_daily_sales
    WHERE open = 1
    GROUP BY store_id
    HAVING promo_days >= 20
       AND non_promo_days >= 20
),

promo_metrics AS (
    SELECT
        store_id,
        promo_days,
        non_promo_days,

        ROUND(
            100.0 * promo_sales / NULLIF(total_sales, 0),
            2
        ) AS promo_sales_share_pct,

        ROUND(
            100.0 * promo_days /
            NULLIF(promo_days + non_promo_days, 0),
            2
        ) AS promo_days_share_pct,

        ROUND(
            100.0 * (promo_avg_sales - non_promo_avg_sales)
            / NULLIF(non_promo_avg_sales, 0),
            2
        ) AS sales_uplift_pct

    FROM promo_performance
),

promo_ranking AS (
    SELECT
        *,
        promo_sales_share_pct - promo_days_share_pct
            AS promo_concentration_gap_pp,

        NTILE(10) OVER (
            ORDER BY
                promo_sales_share_pct - promo_days_share_pct
        ) AS dependence_decile,

        NTILE(10) OVER (
            ORDER BY sales_uplift_pct
        ) AS uplift_decile

    FROM promo_metrics
    WHERE sales_uplift_pct IS NOT NULL
)

SELECT
    store_id,
    promo_days,
    non_promo_days,
    promo_sales_share_pct,
    promo_days_share_pct,
    ROUND(promo_concentration_gap_pp, 2)
        AS promo_concentration_gap_pp,
    sales_uplift_pct,

    CASE
        WHEN dependence_decile = 10
            THEN 'High promotional sales concentration'

        WHEN uplift_decile = 1
            THEN 'Weak promotional uplift'

    END AS promotion_flag

FROM promo_ranking
WHERE dependence_decile = 10
   OR uplift_decile = 1
ORDER BY promo_concentration_gap_pp DESC;

-- ============================================================
-- Q11. How does competition distance and the opening of
--      nearby competitors relate to store performance?
-- ============================================================

-- Part 1: Competition distance
-- Stores are grouped by competitor distance and compared
-- using average daily sales on operating days.
-- Store type and assortment are included for fairer comparisons.

WITH store_performance AS (
    SELECT
        f.store_id,
        s.store_type,
        s.assortment,

        CASE
            WHEN s.competition_distance <= 500 THEN '0-500m'
            WHEN s.competition_distance <= 2000 THEN '501-2000m'
            WHEN s.competition_distance <= 5000 THEN '2001-5000m'
            ELSE 'Over 5000m'
        END AS distance_band,

        AVG(f.sales) AS avg_daily_sales

    FROM fact_daily_sales f
    JOIN dim_store s
        ON f.store_id = s.store_id

    WHERE f.open = 1
      AND s.competition_distance IS NOT NULL

    GROUP BY
        f.store_id,
        s.store_type,
        s.assortment,
        s.competition_distance
)

SELECT
    store_type,
    assortment,
    distance_band,
    COUNT(*) AS store_count,
    ROUND(AVG(avg_daily_sales), 2) AS avg_daily_sales

FROM store_performance
GROUP BY
    store_type,
    assortment,
    distance_band

ORDER BY
    store_type,
    assortment,
    avg_daily_sales DESC;

    -- Part 2: Sales performance before and after competitor opening
-- Compare two complete months before and after the opening month.
-- Only stores with at least 20 open days in each period are included.

WITH competitor_openings AS (
    SELECT
        store_id,
        STR_TO_DATE(
            CONCAT(
                competition_open_since_year, '-',
                LPAD(competition_open_since_month, 2, '0'),
                '-01'
            ),
            '%Y-%m-%d'
        ) AS competitor_open_month

    FROM dim_store
    WHERE competition_open_since_year IS NOT NULL
      AND competition_open_since_month BETWEEN 1 AND 12
),

period_performance AS (
    SELECT
        f.store_id,
        c.competitor_open_month,

        AVG(CASE
            WHEN d.full_date >= DATE_SUB(
                c.competitor_open_month, INTERVAL 2 MONTH
            )
            AND d.full_date < c.competitor_open_month
            THEN f.sales
        END) AS before_avg_sales,

        AVG(CASE
            WHEN d.full_date >= DATE_ADD(
                c.competitor_open_month, INTERVAL 1 MONTH
            )
            AND d.full_date < DATE_ADD(
                c.competitor_open_month, INTERVAL 3 MONTH
            )
            THEN f.sales
        END) AS after_avg_sales,

        COUNT(CASE
            WHEN d.full_date >= DATE_SUB(
                c.competitor_open_month, INTERVAL 2 MONTH
            )
            AND d.full_date < c.competitor_open_month
            THEN 1
        END) AS before_open_days,

        COUNT(CASE
            WHEN d.full_date >= DATE_ADD(
                c.competitor_open_month, INTERVAL 1 MONTH
            )
            AND d.full_date < DATE_ADD(
                c.competitor_open_month, INTERVAL 3 MONTH
            )
            THEN 1
        END) AS after_open_days

    FROM fact_daily_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
    JOIN competitor_openings c
        ON f.store_id = c.store_id

    WHERE f.open = 1

    GROUP BY
        f.store_id,
        c.competitor_open_month
)

SELECT
    store_id,
    competitor_open_month,
    before_open_days,
    after_open_days,
    ROUND(before_avg_sales, 2) AS before_avg_sales,
    ROUND(after_avg_sales, 2) AS after_avg_sales,

    ROUND(
        100.0 * (after_avg_sales - before_avg_sales)
        / NULLIF(before_avg_sales, 0),
        2
    ) AS sales_change_pct

FROM period_performance

WHERE before_open_days >= 20
  AND after_open_days >= 20

ORDER BY sales_change_pct ASC;

-- ============================================================
-- Q12. How do Store Type and Assortment relate to sales,
--      customer traffic, and sales per customer?
-- ============================================================

-- Stores are grouped by store type and assortment to compare
-- average daily sales, customer traffic, and sales per customer.
-- Only operating days are considered.

WITH store_performance AS (
    SELECT
        f.store_id,
        s.store_type,
        s.assortment,
        COUNT(*) AS open_days,
        SUM(f.sales) AS total_sales,
        SUM(f.customers) AS total_customers,
        AVG(f.sales) AS avg_daily_sales,
        AVG(f.customers) AS avg_daily_customers

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
    store_type,
    assortment,

    COUNT(*) AS store_count,

    ROUND(AVG(avg_daily_sales), 2)
        AS avg_daily_sales,

    ROUND(AVG(avg_daily_customers), 2)
        AS avg_daily_customers,

    ROUND(
        SUM(total_sales) / NULLIF(SUM(total_customers), 0),
        2
    ) AS sales_per_customer

FROM store_performance

GROUP BY
    store_type,
    assortment

ORDER BY avg_daily_sales DESC;


-- ============================================================
-- Q13. Are there specific days, months, holidays, or seasonal
--      periods when underperforming stores perform poorly?
--
-- PART 1: SEASONAL PERFORMANCE PATTERNS
-- ============================================================

-- Compare period-specific performance against similar stores.
-- Identify periods when underperforming stores fall further
-- below their usual peer benchmark.
-- Only operating days are included.


-- 1. Overall store performance

WITH store_performance AS (
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


-- 2. Overall peer benchmark

store_benchmark AS (
    SELECT
        *,

        AVG(avg_daily_sales) OVER (
            PARTITION BY store_type, assortment
        ) AS peer_avg_sales

    FROM store_performance
),


-- 3. Identify underperforming stores

underperforming_stores AS (
    SELECT
        store_id,

        100.0 * (avg_daily_sales - peer_avg_sales)
        / NULLIF(peer_avg_sales, 0)
            AS overall_gap_pct

    FROM store_benchmark

    WHERE avg_daily_sales < peer_avg_sales
),


-- 4. Daily sales and calendar information

daily_data AS (
    SELECT
        f.store_id,
        s.store_type,
        s.assortment,
        d.day_of_week,
        d.month,
        f.state_holiday,
        f.school_holiday,
        f.sales

    FROM fact_daily_sales f
    JOIN dim_store s
        ON f.store_id = s.store_id
    JOIN dim_date d
        ON f.date_key = d.date_key

    WHERE f.open = 1
),


-- 5. Performance by calendar period

period_performance AS (

    -- Day of week
    SELECT
        store_id,
        store_type,
        assortment,
        'Day of week' AS period_type,
        CAST(day_of_week AS CHAR) AS period_value,
        COUNT(*) AS open_days,
        AVG(sales) AS avg_daily_sales

    FROM daily_data
    GROUP BY
        store_id, store_type, assortment, day_of_week

    UNION ALL

    -- Month
    SELECT
        store_id,
        store_type,
        assortment,
        'Month',
        CAST(month AS CHAR),
        COUNT(*),
        AVG(sales)

    FROM daily_data
    GROUP BY
        store_id, store_type, assortment, month

    UNION ALL

    -- State holiday
    SELECT
        store_id,
        store_type,
        assortment,
        'State holiday',
        state_holiday,
        COUNT(*),
        AVG(sales)

    FROM daily_data
    GROUP BY
        store_id, store_type, assortment, state_holiday

    UNION ALL

    -- School holiday
    SELECT
        store_id,
        store_type,
        assortment,
        'School holiday',
        CAST(school_holiday AS CHAR),
        COUNT(*),
        AVG(sales)

    FROM daily_data
    GROUP BY
        store_id, store_type, assortment, school_holiday
),


-- 6. Minimum observation requirements

qualified_periods AS (
    SELECT *
    FROM period_performance

    WHERE open_days >= CASE
        WHEN period_type IN (
            'State holiday',
            'School holiday'
        ) THEN 3
        ELSE 5
    END
),


-- 7. Peer benchmark for each calendar period

period_benchmark AS (
    SELECT
        *,

        AVG(avg_daily_sales) OVER (
            PARTITION BY
                store_type,
                assortment,
                period_type,
                period_value
        ) AS peer_avg_daily_sales,

        COUNT(*) OVER (
            PARTITION BY
                store_type,
                assortment,
                period_type,
                period_value
        ) AS peer_group_size

    FROM qualified_periods
),


-- 8. Calculate relative performance gaps

performance_gaps AS (
    SELECT
        p.store_id,
        p.period_type,
        p.period_value,
        u.overall_gap_pct,

        100.0 * (
            p.avg_daily_sales - p.peer_avg_daily_sales
        )
        / NULLIF(p.peer_avg_daily_sales, 0)
            AS period_gap_pct

    FROM period_benchmark p
    JOIN underperforming_stores u
        ON p.store_id = u.store_id

    WHERE p.peer_group_size >= 3
)


-- 9. Summary by calendar period

SELECT
    period_type,
    period_value,

    COUNT(DISTINCT store_id) AS stores_analysed,

    ROUND(
        AVG(period_gap_pct),
        2
    ) AS avg_period_gap_pct,

    ROUND(
        AVG(overall_gap_pct),
        2
    ) AS avg_overall_gap_pct,

    ROUND(
        AVG(period_gap_pct - overall_gap_pct),
        2
    ) AS additional_gap_pp

FROM performance_gaps

GROUP BY
    period_type,
    period_value

ORDER BY
    FIELD(
        period_type,
        'Day of week',
        'Month',
        'State holiday',
        'School holiday'
    ),
    additional_gap_pp ASC;

-- ============================================================
-- Q13. Which stores experience the largest Saturday
--      underperformance compared with similar stores?
--
-- PART 2: STORE-LEVEL SATURDAY UNDERPERFORMANCE
-- ============================================================

-- Compare Saturday average daily sales against peer benchmarks.
-- Identify stores whose Saturday performance is particularly
-- weak compared with their usual relative performance.
-- Only operating days are included.


-- 1. Overall store performance

WITH store_performance AS (
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


-- 2. Overall peer benchmark

store_benchmark AS (
    SELECT
        *,

        AVG(avg_daily_sales) OVER (
            PARTITION BY store_type, assortment
        ) AS peer_avg_sales

    FROM store_performance
),


-- 3. Identify underperforming stores

underperforming_stores AS (
    SELECT
        store_id,
        store_type,
        assortment,

        100.0 * (
            avg_daily_sales - peer_avg_sales
        )
        / NULLIF(peer_avg_sales, 0)
            AS overall_gap_pct

    FROM store_benchmark

    WHERE avg_daily_sales < peer_avg_sales
),


-- 4. Saturday sales performance

saturday_performance AS (
    SELECT
        f.store_id,
        s.store_type,
        s.assortment,

        COUNT(*) AS saturday_open_days,
        AVG(f.sales) AS saturday_avg_sales

    FROM fact_daily_sales f

    JOIN dim_store s
        ON f.store_id = s.store_id

    JOIN dim_date d
        ON f.date_key = d.date_key

    WHERE f.open = 1
      AND d.day_of_week = 6

    GROUP BY
        f.store_id,
        s.store_type,
        s.assortment

    HAVING COUNT(*) >= 5
),


-- 5. Saturday peer benchmark

saturday_benchmark AS (
    SELECT
        *,

        AVG(saturday_avg_sales) OVER (
            PARTITION BY store_type, assortment
        ) AS peer_saturday_avg_sales,

        COUNT(*) OVER (
            PARTITION BY store_type, assortment
        ) AS peer_group_size

    FROM saturday_performance
),


-- 6. Calculate Saturday performance gaps

performance_gaps AS (
    SELECT
        s.store_id,
        s.store_type,
        s.assortment,
        s.saturday_open_days,
        s.saturday_avg_sales,
        s.peer_saturday_avg_sales,
        s.peer_group_size,

        u.overall_gap_pct,

        100.0 * (
            s.saturday_avg_sales - s.peer_saturday_avg_sales
        )
        / NULLIF(s.peer_saturday_avg_sales, 0)
            AS saturday_gap_pct

    FROM saturday_benchmark s

    JOIN underperforming_stores u
        ON s.store_id = u.store_id

    WHERE s.peer_group_size >= 3
)


-- 7. Top 10 largest negative Saturday performance gaps

SELECT
    store_id,
    store_type,
    assortment,
    saturday_open_days,
    peer_group_size,

    ROUND(saturday_avg_sales, 2)
        AS saturday_avg_sales,

    ROUND(peer_saturday_avg_sales, 2)
        AS peer_saturday_avg_sales,

    ROUND(overall_gap_pct, 2)
        AS overall_gap_pct,

    ROUND(saturday_gap_pct, 2)
        AS saturday_gap_pct,

    ROUND(
        saturday_gap_pct - overall_gap_pct,
        2
    ) AS additional_gap_pp

FROM performance_gaps

ORDER BY saturday_gap_pct ASC

LIMIT 10;