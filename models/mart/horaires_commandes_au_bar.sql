WITH qty_beer AS (
SELECT 
time_trunc(TIME(date_transaction), MINUTE) AS time_time,
item_clean_cat_simple,
SUM(qty) AS qty_beer
FROM {{ ref('bar_transactions') }}
GROUP BY time_time, item_clean_cat_simple
HAVING item_clean_cat_simple LIKE "beer"
ORDER BY time_time
),

qty_cocktail_elabore AS (
SELECT 
time_trunc(TIME(date_transaction), MINUTE) AS time_time,
item_clean_cat_simple,
SUM(qty) AS qty_cocktail_elabore
FROM {{ ref('bar_transactions') }}
GROUP BY time_time, item_clean_cat_simple
HAVING item_clean_cat_simple LIKE "cocktail elabor%"
ORDER BY time_time
),

qty_vin AS (
SELECT 
time_trunc(TIME(date_transaction), MINUTE) AS time_time,
item_clean_cat_simple,
SUM(qty) AS qty_vin
FROM {{ ref('bar_transactions') }}
GROUP BY time_time, item_clean_cat_simple
HAVING item_clean_cat_simple LIKE "vin"
ORDER BY time_time
),

qty_soft AS (
SELECT 
time_trunc(TIME(date_transaction), MINUTE) AS time_time,
item_clean_cat_simple,
SUM(qty) AS qty_soft
FROM {{ ref('bar_transactions') }}
GROUP BY time_time, item_clean_cat_simple
HAVING item_clean_cat_simple LIKE "soft"
ORDER BY time_time
),

qty_tot AS (
SELECT 
time_trunc(TIME(date_transaction), MINUTE) AS time_time,
SUM(qty) AS qty_commandes
FROM {{ ref('bar_transactions') }}
GROUP BY time_time
ORDER BY time_time
),

qty_cat AS (
SELECT
t.time_time,
b.qty_beer,
c.qty_cocktail_elabore,
v.qty_vin,
s.qty_soft,
t.qty_commandes
FROM qty_tot AS t
LEFT JOIN qty_beer AS b
USING(time_time)
LEFT JOIN qty_cocktail_elabore AS c
USING(time_time)
LEFT JOIN qty_vin AS v
USING(time_time)
LEFT JOIN qty_soft AS s
USING(time_time)
ORDER BY t.time_time
)

SELECT
time_time,
qty_beer,
qty_cocktail_elabore,
qty_vin,
qty_commandes,
CASE
    WHEN time_time BETWEEN '14:00:00' AND '18:00:00' THEN ROUND(qty_beer*7/2,0)
    ELSE qty_beer
END AS qty_beer_scaled,
CASE
    WHEN time_time BETWEEN '14:00:00' AND '18:00:00' THEN ROUND(qty_cocktail_elabore*7/2,0)
    ELSE qty_cocktail_elabore
END AS qty_cocktail_elabore_scaled,
CASE
    WHEN time_time BETWEEN '14:00:00' AND '18:00:00' THEN ROUND(qty_vin*7/2,0)
    ELSE qty_vin
END AS qty_vin_scaled,
CASE
    WHEN time_time BETWEEN '14:00:00' AND '18:00:00' THEN ROUND(qty_soft*7/2,0)
    ELSE qty_soft
END AS qty_soft_scaled,
CASE
    WHEN time_time BETWEEN '14:00:00' AND '18:00:00' THEN ROUND(qty_commandes*7/2,0)
    ELSE qty_commandes
END AS qty_commandes_scaled

FROM qty_cat
--ok