-- ============================================================
-- ROSSMANN STORE SALES
-- DATABASE SETUP, DATA LOAD AND VALIDATION
-- ============================================================


-- ============================================================
-- 1. CREATE DATABASE
-- ============================================================

CREATE DATABASE IF NOT EXISTS rossmann;
USE rossmann;


-- ============================================================
-- 2. DROP EXISTING TABLES
-- Drop fact table first because it depends on the dimensions.
-- ============================================================

DROP TABLE IF EXISTS fact_daily_sales;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_store;


-- ============================================================
-- 3. CREATE DIM_STORE
-- One row = one Rossmann store
-- ============================================================

CREATE TABLE dim_store (
    store_id INT PRIMARY KEY,
    store_type CHAR(1),
    assortment CHAR(1),
    competition_distance DECIMAL(10,2),
    competition_open_since_month INT,
    competition_open_since_year INT,
    promo2 TINYINT(1),
    promo2_since_week INT,
    promo2_since_year INT,
    promo_interval VARCHAR(50)
);


-- ============================================================
-- 4. CREATE DIM_DATE
-- One row = one calendar date
-- ============================================================

CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE UNIQUE NOT NULL,
    day_of_week INT,
    day INT,
    week INT,
    month INT,
    quarter INT,
    year INT,
    is_weekend TINYINT(1)
);


-- ============================================================
-- 5. CREATE FACT_DAILY_SALES
-- Grain: one row = one store on one date
-- ============================================================

CREATE TABLE fact_daily_sales (
    store_id INT NOT NULL,
    date_key INT NOT NULL,
    sales INT,
    customers INT,
    open TINYINT(1),
    promo TINYINT(1),
    state_holiday CHAR(1),
    school_holiday TINYINT(1),

    PRIMARY KEY (store_id, date_key),

    CONSTRAINT fk_sales_store
        FOREIGN KEY (store_id)
        REFERENCES dim_store(store_id),

    CONSTRAINT fk_sales_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key)
);


-- ============================================================
-- 6. CHECK DATABASE STRUCTURE AND SERVER IMPORT DIRECTORY
-- ============================================================

SHOW TABLES;
SELECT @@secure_file_priv AS secure_file_directory;


-- ============================================================
-- 7. LOAD DIM_STORE
-- Source: cleaned store dataset
-- The CSV uses Windows CRLF line endings.
-- ============================================================

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 26.7/Uploads/store_clean.csv'
INTO TABLE dim_store
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    @store,
    @store_type,
    @assortment,
    @competition_distance,
    @competition_open_since_month,
    @competition_open_since_year,
    @promo2,
    @promo2_since_week,
    @promo2_since_year,
    @promo_interval
)
SET
    store_id = @store,
    store_type = NULLIF(@store_type, ''),
    assortment = NULLIF(@assortment, ''),
    competition_distance = NULLIF(@competition_distance, ''),
    competition_open_since_month = NULLIF(@competition_open_since_month, ''),
    competition_open_since_year = NULLIF(@competition_open_since_year, ''),
    promo2 = NULLIF(@promo2, ''),
    promo2_since_week = NULLIF(@promo2_since_week, ''),
    promo2_since_year = NULLIF(@promo2_since_year, ''),
    promo_interval = NULLIF(@promo_interval, '');


-- ============================================================
-- 8. LOAD DIM_DATE
-- Source: cleaned train dataset
-- Each date occurs for many stores. IGNORE skips duplicate date keys.
-- ============================================================

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 26.7/Uploads/train_clean.csv'
IGNORE
INTO TABLE dim_date
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    @store,
    @day_of_week,
    @date,
    @sales,
    @customers,
    @open,
    @promo,
    @state_holiday,
    @school_holiday
)
SET
    date_key = CAST(
        DATE_FORMAT(
            STR_TO_DATE(@date, '%Y-%m-%d'),
            '%Y%m%d'
        ) AS UNSIGNED
    ),
    full_date = STR_TO_DATE(@date, '%Y-%m-%d'),
    day_of_week = NULLIF(@day_of_week, ''),
    day = DAY(STR_TO_DATE(@date, '%Y-%m-%d')),
    week = WEEK(STR_TO_DATE(@date, '%Y-%m-%d'), 3),
    month = MONTH(STR_TO_DATE(@date, '%Y-%m-%d')),
    quarter = QUARTER(STR_TO_DATE(@date, '%Y-%m-%d')),
    year = YEAR(STR_TO_DATE(@date, '%Y-%m-%d')),
    is_weekend = CASE
        WHEN @day_of_week IN ('6', '7') THEN 1
        ELSE 0
    END;


-- ============================================================
-- 9. LOAD FACT_DAILY_SALES
-- Source: cleaned train dataset
-- ============================================================

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 26.7/Uploads/train_clean.csv'
INTO TABLE fact_daily_sales
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    @store,
    @day_of_week,
    @date,
    @sales,
    @customers,
    @open,
    @promo,
    @state_holiday,
    @school_holiday
)
SET
    store_id = @store,
    date_key = CAST(
        DATE_FORMAT(
            STR_TO_DATE(@date, '%Y-%m-%d'),
            '%Y%m%d'
        ) AS UNSIGNED
    ),
    sales = NULLIF(@sales, ''),
    customers = NULLIF(@customers, ''),
    open = NULLIF(@open, ''),
    promo = NULLIF(@promo, ''),
    state_holiday = NULLIF(@state_holiday, ''),
    school_holiday = NULLIF(@school_holiday, '');


-- ============================================================
-- 10. VALIDATE ROW COUNTS
-- ============================================================

SELECT COUNT(*) AS store_rows
FROM dim_store;

SELECT COUNT(*) AS date_rows
FROM dim_date;

SELECT COUNT(*) AS sales_rows
FROM fact_daily_sales;


-- ============================================================
-- 11. CHECK SAMPLE DATA
-- ============================================================

SELECT *
FROM dim_store
LIMIT 10;

SELECT *
FROM dim_date
ORDER BY full_date
LIMIT 10;

SELECT *
FROM fact_daily_sales
LIMIT 10;


-- ============================================================
-- 12. CHECK PRIMARY KEY UNIQUENESS
-- Expected result: no rows returned by any query.
-- ============================================================

SELECT
    store_id,
    COUNT(*) AS occurrences
FROM dim_store
GROUP BY store_id
HAVING COUNT(*) > 1;

SELECT
    date_key,
    COUNT(*) AS occurrences
FROM dim_date
GROUP BY date_key
HAVING COUNT(*) > 1;

SELECT
    store_id,
    date_key,
    COUNT(*) AS occurrences
FROM fact_daily_sales
GROUP BY store_id, date_key
HAVING COUNT(*) > 1;


-- ============================================================
-- 13. CHECK FOREIGN KEY INTEGRITY
-- Expected result for both counts: 0.
-- ============================================================

SELECT
    COUNT(*) AS missing_store_keys
FROM fact_daily_sales f
LEFT JOIN dim_store s
    ON f.store_id = s.store_id
WHERE s.store_id IS NULL;

SELECT
    COUNT(*) AS missing_date_keys
FROM fact_daily_sales f
LEFT JOIN dim_date d
    ON f.date_key = d.date_key
WHERE d.date_key IS NULL;


-- ============================================================
-- 14. CHECK FINAL STAR SCHEMA
-- ============================================================

SELECT
    f.store_id,
    d.full_date,
    f.sales,
    f.customers,
    f.promo,
    s.store_type,
    s.assortment
FROM fact_daily_sales f
JOIN dim_store s
    ON f.store_id = s.store_id
JOIN dim_date d
    ON f.date_key = d.date_key
LIMIT 10;
