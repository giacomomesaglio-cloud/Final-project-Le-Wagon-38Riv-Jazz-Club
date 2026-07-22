SELECT

-- BLOC BAR

j.day_of_the_week,
b.date_concert,
COUNT(*) OVER(PARTITION BY DATE(date_concert)) AS nb_concert_par_jour,
j.creneau,
j.date_creneau,
j.qty_bar,
j.turnover AS recettes_bar,

-- BLOC CONCERTS COUTS

-- Définir un score d'accessibilite de 2 par défaut pour toutes les jam
CASE
    WHEN j.date_creneau LIKE "%late%"
    THEN 2
    ELSE j.accessibilite_score
END AS accessibilite_score,
-- Assigner un type de contrat 
-- 1) pour les NULL : Coréa 50/50 par défaut
-- 2) pour les Jam
CASE 
    WHEN j.type_contrat IS NULL AND j.creneau NOT LIKE 'late%' THEN 'Coréa 50/50'
    WHEN j.type_contrat IS NULL AND j.creneau LIKE 'late%' THEN 'late jam'
    ELSE j.type_contrat
END AS type_contrat,
j.nb_cachet,
j.montant_cachet_unitaire,
j.montant_cession,
j.montant_ht_facture,
-- Création d'un montant_corea pour appliquer le taux correspondant sur la base des recettes_billetterie
CASE
    WHEN j.type_contrat LIKE 'Coréa 50%' THEN ROUND(b.recettes_billetterie*0.5,2)
    WHEN j.type_contrat LIKE 'Coréa 55%' THEN ROUND(b.recettes_billetterie*0.55,2)
    ELSE 0
END AS montant_corea,
-- Création d'un montant_jam sur la base des tarifs qui sont fixes (données gérants)
CASE
    WHEN j.date_concert < '2025-09-01' 
        AND j.type_contrat IS NULL
        AND j.creneau LIKE 'late%' THEN 210
    WHEN j.date_concert >= '2025-09-01'
        AND j.type_contrat IS NULL
        AND j.creneau LIKE 'late%'
        AND j.day_of_the_week IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday') THEN 330
    WHEN j.date_concert >= '2025-09-01'
        AND j.type_contrat IS NULL
        AND j.creneau LIKE 'late%'
        AND j.day_of_the_week IN ('Saturday', 'Sunday') THEN 600
    ELSE 0
END AS montant_jam,
j.doublon_charges_artistiques,

-- BLOC BILLETTERIE 

b.nom_du_projet,
b.recettes_billetterie,
b.tot_places_vendues,
-- Taux de remplissage parfois supérieur à 100% car no-show ou jam (entrées-sorties régulières)
CASE 
    WHEN b.tx_remplissage > 100 THEN 100
    ELSE b.tx_remplissage    
END AS tx_remplissage,
b.tarif_moyen,
b.plein_tarif,
b.pct_guichet,
b.pct_web,
b.pct_invitation,
b.pct_payed,
b.pct_plein_tarif,
b.pct_tarif_reduit,
b.session_JHJ,
b.session_JH,
b.typologie,

-- BLOC GAIN

-- Tinhinane c'est à toi de jouer maintenant

-- BLOC METEO

b.precipitations,
b.temp_moy,
b.vent_moy,
b.duree_insolation,
b.score_m,
b.score_ensoleillement,
b.meteo,
b.jour_creneau,
b.jour_fr

FROM {{ ref('billetterie_complet_groupby') }} AS b
LEFT JOIN {{ ref('join_bar_couts') }} AS j
USING (date_concert)

-- Périmètre d'analyse de 2024 jusqu'à mai 2026
WHERE date_concert BETWEEN '2024-01-01' AND '2026-05-31' 
--OR b.nom_du_projet NOT LIKE '%T-shirt%|Totebag%'  