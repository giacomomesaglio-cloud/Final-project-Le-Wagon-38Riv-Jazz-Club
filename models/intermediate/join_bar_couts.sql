SELECT
b.day_of_the_week,
b.date_concert,
b.creneau,
b.date_creneau,
b.qty_bar,
b.turnover,
CASE
    WHEN b.date_creneau LIKE "%late%"
    THEN 2
    ELSE c.accessibilite_score
END AS accessibilite_score,
c.type_contrat,
c.nb_cachet,
c.montant_cachet_unitaire,
c.montant_cession,
c.montant_ht_facture,
c.doublon_charges_artistiques

FROM {{ ref('bar_transactions_concert') }} AS b
LEFT JOIN {{ ref('concerts_couts') }} AS c
USING (date_creneau)