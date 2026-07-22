with 

source as (

    select * from {{ source('raw_data_38', 'bar_transactions_') }}

),

mapping as (

    select * from {{ ref('mapping_item') }}

),

renamed AS (

    SELECT
        source,
        date_transaction,
        LOWER(s.item) AS item_clean,
        m.item_clean_cat, --category crée avec le csv mapping
        qty,
        unit_price_eur,
        final_price_eur,
        discount_eur,
        pre_tax_eur,
        tax_amount_eur,
        tax_rate_pct,
        
    FROM source AS s
    LEFT JOIN mapping AS m
    ON LOWER(s.item) = m.item
    --J'ai enlevé les "annulé" et j'ai mis un filtre sur la periode 01/01/2024-31/05/2026
    WHERE LOWER(s.item) NOT LIKE '%(annul%)%' AND date_transaction BETWEEN '2024-01-01 00:12:00' AND '2026-06-01 00:00:00'
    ORDER BY date_transaction

),

concert AS (

SELECT 
CASE
  WHEN TIME(date_transaction) < '14:25:00' THEN CAST(CONCAT(DATE(date_transaction)-1, ' ', '23:00:00 UTC') AS TIMESTAMP)
  WHEN TIME(date_transaction) BETWEEN '14:25:01' AND '16:25:00' THEN CAST(CONCAT(DATE(date_transaction), ' ', '15:00:00 UTC') AS TIMESTAMP)
  WHEN TIME(date_transaction) BETWEEN '16:25:01' AND '18:55:00' THEN CAST(CONCAT(DATE(date_transaction), ' ', '17:00:00 UTC') AS TIMESTAMP)
  WHEN TIME(date_transaction) BETWEEN '18:55:01' AND '20:55:00' THEN CAST(CONCAT(DATE(date_transaction), ' ', '19:30:00 UTC') AS TIMESTAMP)
  WHEN TIME(date_transaction) BETWEEN '20:55:01' AND '22:25:00' THEN CAST(CONCAT(DATE(date_transaction), ' ', '21:30:00 UTC') AS TIMESTAMP)
  ELSE CAST(CONCAT(DATE(date_transaction), ' ', '23:00:00 UTC') AS TIMESTAMP)
END AS date_concert, 
*
from renamed
)

SELECT
FORMAT_TIMESTAMP('%A', date_concert) AS day_of_the_week, --ajouté day of the week
date_concert,
CASE 
    WHEN FORMAT_TIMESTAMP('%A', date_concert) IN ('Sunday', 'Saturday')
        AND TIME(date_concert) IN ('15:00:00', '17:00:00') 
        THEN 'apres_midi'
    WHEN TIME(date_concert) IN ('19:30:00', '21:30:00') 
        THEN 'soir'
    WHEN FORMAT_TIMESTAMP('%A', date_concert) NOT IN ('Sunday', 'Saturday')
        AND TIME(date_concert) < TIME '19:30:00'
        THEN 'late_jam'
    ELSE 'late_jam'
END AS creneau,
date_transaction,
item_clean,
item_clean_cat,
CASE 
    WHEN item_clean_cat LIKE 'cocktail elabore%' THEN 'cocktail elabore'
    WHEN item_clean_cat LIKE 'virgin%' THEN 'virgin cocktail'
    ELSE item_clean_cat
END AS item_clean_cat_simple, --nouvelle categorie avec tous les cocktails elaboré ensemble!
qty,
pre_tax_eur,

FROM concert