SELECT
day_of_the_week,
date_concert,
creneau,
CONCAT(DATE(date_concert), " - ", creneau) AS date_creneau,
ROUND(SUM(qty),0) AS qty_bar,
ROUND(SUM(pre_tax_eur),2) AS turnover
FROM {{ ref('bar_transactions') }}
GROUP BY date_concert, creneau, date_creneau, day_of_the_week