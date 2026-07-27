/* ============================================================================
   BLINKIT GROCERY DATA — SQL ANALYSIS
   ============================================================================
   Author  : Aman Kumar
   Purpose : Recreates the core Power BI dashboard KPIs and insights using
             pure SQL — demonstrating the same analysis (Total Sales, Avg
             Sales, Ratings, Outlet performance) via relational queries
             instead of DAX. Written for MySQL / PostgreSQL compatible syntax.

   Source  : data/BlinkIT_Grocery_Data.xlsx  (8,523 rows, 12 columns)
   ============================================================================ */


-- ============================================================================
-- 1. DATABASE & TABLE SETUP
-- ============================================================================

CREATE DATABASE IF NOT EXISTS blinkit_analytics;
USE blinkit_analytics;

DROP TABLE IF EXISTS blinkit_sales;

CREATE TABLE blinkit_sales (
    item_identifier             VARCHAR(15)     NOT NULL,
    item_fat_content            VARCHAR(20)     NOT NULL,   -- 'Low Fat' / 'Regular'
    item_type                   VARCHAR(50)     NOT NULL,   -- e.g. 'Fruits and Vegetables'
    item_weight                 DECIMAL(6,2),
    item_visibility              DECIMAL(10,8)   NOT NULL,
    outlet_identifier            VARCHAR(15)     NOT NULL,
    outlet_establishment_year    INT              NOT NULL,
    outlet_size                  VARCHAR(10),               -- 'Small' / 'Medium' / 'High'
    outlet_location_type         VARCHAR(10)     NOT NULL,   -- 'Tier 1' / 'Tier 2' / 'Tier 3'
    outlet_type                  VARCHAR(30)     NOT NULL,   -- 'Grocery Store' / 'Supermarket Type1' ...
    sales                        DECIMAL(10,4)   NOT NULL,
    rating                       DECIMAL(2,1)    NOT NULL,

    PRIMARY KEY (item_identifier, outlet_identifier)
);

-- Data is loaded from BlinkIT_Grocery_Data.xlsx via ETL / LOAD DATA INFILE
-- (converted to CSV) or through a Python/pandas -> to_sql() pipeline.


-- ============================================================================
-- 2. TOP-LEVEL KPI CARDS  (mirrors the Power BI dashboard header)
-- ============================================================================

-- 2.1 Total Sales
SELECT ROUND(SUM(sales), 2) AS total_sales
FROM blinkit_sales;

-- 2.2 Average Sales per Item
SELECT ROUND(AVG(sales), 2) AS average_sales
FROM blinkit_sales;

-- 2.3 Average Customer Rating
SELECT ROUND(AVG(rating), 1) AS average_rating
FROM blinkit_sales;

-- 2.4 Total Number of Items Sold
SELECT COUNT(*) AS number_of_items
FROM blinkit_sales;


-- ============================================================================
-- 3. FAT CONTENT ANALYSIS
-- ============================================================================

SELECT
    item_fat_content,
    ROUND(SUM(sales), 2)                                   AS total_sales,
    ROUND(SUM(sales) * 100.0 / (SELECT SUM(sales) FROM blinkit_sales), 1) AS pct_of_total_sales
FROM blinkit_sales
GROUP BY item_fat_content
ORDER BY total_sales DESC;


-- ============================================================================
-- 4. FAT CONTENT BY OUTLET LOCATION TIER
-- ============================================================================

SELECT
    outlet_location_type,
    item_fat_content,
    ROUND(SUM(sales), 2) AS total_sales
FROM blinkit_sales
GROUP BY outlet_location_type, item_fat_content
ORDER BY outlet_location_type, total_sales DESC;


-- ============================================================================
-- 5. ITEM TYPE-WISE SALES  (ranked, matches dashboard bar chart)
-- ============================================================================

SELECT
    item_type,
    ROUND(SUM(sales), 2)   AS total_sales,
    COUNT(*)                AS item_count
FROM blinkit_sales
GROUP BY item_type
ORDER BY total_sales DESC;


-- ============================================================================
-- 6. OUTLET SIZE DISTRIBUTION
-- ============================================================================

SELECT
    outlet_size,
    ROUND(SUM(sales), 2) AS total_sales,
    COUNT(DISTINCT outlet_identifier) AS num_outlets
FROM blinkit_sales
GROUP BY outlet_size
ORDER BY total_sales DESC;


-- ============================================================================
-- 7. OUTLET LOCATION (TIER) ANALYSIS
-- ============================================================================

SELECT
    outlet_location_type,
    ROUND(SUM(sales), 2)                                                  AS total_sales,
    ROUND(SUM(sales) * 100.0 / (SELECT SUM(sales) FROM blinkit_sales), 1) AS pct_of_total_sales
FROM blinkit_sales
GROUP BY outlet_location_type
ORDER BY total_sales DESC;


-- ============================================================================
-- 8. OUTLET ESTABLISHMENT TREND  (sales by year outlet was opened)
-- ============================================================================

SELECT
    outlet_establishment_year,
    ROUND(SUM(sales), 2) AS total_sales
FROM blinkit_sales
GROUP BY outlet_establishment_year
ORDER BY outlet_establishment_year;


-- ============================================================================
-- 9. OUTLET TYPE COMPARISON TABLE
--    (Grocery Store vs Supermarket Type1/2/3 — matches dashboard table)
-- ============================================================================

SELECT
    outlet_type,
    ROUND(SUM(sales), 2)          AS total_sales,
    COUNT(*)                      AS number_of_items,
    ROUND(AVG(sales), 2)          AS avg_sales,
    ROUND(AVG(rating), 1)         AS avg_rating,
    ROUND(AVG(item_visibility), 2) AS avg_item_visibility
FROM blinkit_sales
GROUP BY outlet_type
ORDER BY total_sales DESC;


-- ============================================================================
-- 10. TOP 5 BEST-SELLING ITEM TYPES PER OUTLET TIER (window function)
-- ============================================================================

WITH ranked_sales AS (
    SELECT
        outlet_location_type,
        item_type,
        SUM(sales) AS total_sales,
        RANK() OVER (
            PARTITION BY outlet_location_type
            ORDER BY SUM(sales) DESC
        ) AS sales_rank
    FROM blinkit_sales
    GROUP BY outlet_location_type, item_type
)
SELECT outlet_location_type, item_type, ROUND(total_sales, 2) AS total_sales
FROM ranked_sales
WHERE sales_rank <= 5
ORDER BY outlet_location_type, sales_rank;


-- ============================================================================
-- 11. OUTLETS WITH ABOVE-AVERAGE RATING BUT BELOW-AVERAGE SALES
--     (identifies underperforming-but-well-liked outlets — actionable insight)
-- ============================================================================

SELECT
    outlet_identifier,
    ROUND(AVG(rating), 1) AS avg_rating,
    ROUND(SUM(sales), 2)  AS total_sales
FROM blinkit_sales
GROUP BY outlet_identifier
HAVING AVG(rating) > (SELECT AVG(rating) FROM blinkit_sales)
   AND SUM(sales)  < (SELECT AVG(outlet_total) FROM (
                          SELECT SUM(sales) AS outlet_total
                          FROM blinkit_sales
                          GROUP BY outlet_identifier
                      ) AS outlet_totals)
ORDER BY total_sales ASC;


-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
