WITH subquery as(

SELECT 
*
,CASE
    WHEN h_1er_set < TIME '18:00:00' THEN 'apres_midi'
    WHEN h_1er_set < TIME '23:00:00' THEN 'soir'
    ELSE 'late_jam'
END AS creneau,

FROM {{ ref('stg_raw_data_38__concerts_couts_') }}

) 

SELECT 

    c.id AS id_concerts_couts,
    c.nom_du_projet,
    n.accessibilite_score,
    c.date_concert,
    c.h_1er_set,
    c.h_2e_set,
    CONCAT(c.date_concert, ' - ', c.creneau) AS date_creneau,
    c.type_contrat,
    c.nb_cachet,
    c.montant_cachet_unitaire,
    c.montant_cession,
    c.montant_ht_facture,

    -- Indique s'il faudra dédoublonner les charges artistiques ou pas lorsque la jointure sera faite sur la table billetterie
    -- Si Coréa = Ne pas dédoublonner (Single)
    -- Si 1 set = Ne pas dédoublonner (Single)
    -- Si 2 sets hors Coréa = Dédoublonner (Doublon)
    CASE 
        WHEN c.h_1er_set IS NOT NULL 
            AND c.h_2e_set IS NOT NULL 
            AND c.type_contrat NOT LIKE 'Coréa%'
        THEN 'Doublon'
        ELSE 'Single'
    END AS doublon_charges_artistiques,





FROM subquery AS c
LEFT JOIN {{ ref('stg_raw_data_38__niveau_accessibilite') }} AS n
ON c.id = n.id
