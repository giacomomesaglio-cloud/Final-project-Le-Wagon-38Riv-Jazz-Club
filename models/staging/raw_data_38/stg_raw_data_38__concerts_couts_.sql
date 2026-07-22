with 

source as (

    select * from {{ source('raw_data_38', 'concerts_couts_') }}

),

complete as (
    select * from {{ ref('nb_cachet_complete') }}
),


factures as (
    select
        *,
        SAFE.PARSE_TIME('%H:%M', TRIM(heure_1er_set)) AS h_1er_set,
        SAFE.PARSE_TIME('%H:%M', TRIM(heure_2e_set))  AS h_2e_set,
        COALESCE(SAFE_CAST(nb_factures AS INT64), 0)            AS nb_factures_clean,
        COALESCE(SAFE_CAST(montant_facture_unitaire AS FLOAT64), 0) AS montant_facture_unitaire_clean,
        COALESCE(SAFE_CAST(montant_ht_facture AS FLOAT64), 0)   AS montant_ht_facture_clean
    from source
),

renamed as (

    select
        s.id,
        s.nom_du_projet,
        s.date_concert,
        s.h_1er_set,
        s.h_2e_set,
        s.formation,
        s.lineup,

        -- Si type_contrat = Mixte et la rémunération est une facture sans montant, on passe le type_contrat en "Coréa 50/50"
        -- Si type_contrat = Mixte mais que des factures avec montant en rémunération, on passe le type contrat en 'Facturation'
        -- Cleaning dénomination Coréa
        CASE
            WHEN s.conditions = 'Mixte'
                AND COALESCE(SAFE_CAST(s.nb_cachets AS INT64), 0) = 0
                AND COALESCE(SAFE_CAST(REGEXP_REPLACE(s.montant_cachet_unitaire, r'[^0-9.]', '') AS FLOAT64), 0) = 0
                AND COALESCE(SAFE_CAST(s.montant_cession AS FLOAT64), 0) = 0
                AND s.nb_factures_clean > 0
                AND (s.montant_facture_unitaire_clean > 0 OR s.montant_ht_facture_clean > 0)
                THEN 'Facturation'
            WHEN s.conditions = 'Mixte'
                AND s.nb_factures_clean > 0
                AND s.montant_facture_unitaire_clean = 0
                AND s.montant_ht_facture_clean = 0
                THEN 'Coréa 50/50'
            WHEN s.conditions = 'Coréa 55/45 aprem' THEN 'Coréa 55/45'
            WHEN s.conditions = 'Coréa 45/55'       THEN 'Coréa 55/45'
            ELSE s.conditions
        END AS type_contrat,


        -- Pour le type_contrat "Cachets", si le nb_cachet est vide, alors on se réfère à la formation, au lineup, au nom_du_projet, enfin au seed
        CASE
            WHEN s.conditions = 'Cachets' THEN
                COALESCE(
                    SAFE_CAST(s.nb_cachets AS INT64),
                    CASE 
                        WHEN s.formation = 'Solo'             THEN 1
                        WHEN s.formation = 'Duo'              THEN 2
                        WHEN s.formation = 'Trio'             THEN 3
                        WHEN s.formation = 'Quartet'          THEN 4
                        WHEN s.formation = 'Quintet'          THEN 5
                        WHEN s.formation = 'Sextet'           THEN 6
                        WHEN s.formation = 'Grande formation' THEN 
                            ARRAY_LENGTH(SPLIT(s.lineup, '|'))
                        ELSE NULL
                    END,
                    CASE
                        WHEN LOWER(s.nom_du_projet) LIKE '%solo%'     THEN 1
                        WHEN LOWER(s.nom_du_projet) LIKE '%duo%'      THEN 2
                        WHEN LOWER(s.nom_du_projet) LIKE '%trio%'     THEN 3
                        WHEN LOWER(s.nom_du_projet) LIKE '%quartet%'  THEN 4
                        WHEN LOWER(s.nom_du_projet) LIKE '%quintet%'  THEN 5
                        WHEN LOWER(s.nom_du_projet) LIKE '%sextet%'   THEN 6
                        ELSE NULL
                    END,
                    c.nb_cachet_clean
                )
            ELSE 0
        END AS nb_cachet,

        -- Permet de passer les montant_cachet_unitaire de string à float
        -- Passer le montant à 0 si le contrat est une Cession, Coréa, Facturation, Mixte
        -- Lorsque type_contrat = "Cachets" et que montant_cachet_unitaire = 0, remplir par défaut avec un montant à 100
        CASE
            WHEN s.conditions = 'Cession' THEN 0
            WHEN s.conditions LIKE '%Coréa%' THEN 0
            WHEN s.conditions = 'Mixte' THEN 0
            WHEN s.conditions = 'Facturation' THEN 0
            WHEN s.conditions = 'Cachets' THEN
                COALESCE(
                    NULLIF(SAFE_CAST(REGEXP_REPLACE(s.montant_cachet_unitaire, r'[^0-9.]', '') AS FLOAT64), 0),
                    100
                )
            ELSE
                COALESCE(
                    SAFE_CAST(REGEXP_REPLACE(s.montant_cachet_unitaire, r'[^0-9.]', '') AS FLOAT64),
                    0
                )
        END AS montant_cachet_unitaire,

        -- Si contrat cession et info du montant dans cachet_unitaire, la passer dans montant_cession
        CASE
            WHEN s.conditions = 'Cession' THEN
                COALESCE(
                    NULLIF(SAFE_CAST(s.montant_cession AS FLOAT64), 0),
                    SAFE_CAST(REGEXP_REPLACE(s.montant_cachet_unitaire, r'[^0-9.]', '') AS FLOAT64)
                )
            ELSE
                COALESCE(SAFE_CAST(s.montant_cession AS FLOAT64), 0)
        END AS montant_cession,
        
        
        -- Passer le nombre de facture à 0 si pas de montant associé
        CASE
            WHEN s.nb_factures_clean > 0
                AND s.montant_facture_unitaire_clean = 0
                AND s.montant_ht_facture_clean = 0
                THEN 0
            ELSE s.nb_factures_clean
        END AS nb_factures,


        -- Si montant_facture_unitaire vide, = montant_ht_facture / nb_factures
        -- Si nb_factures = 0, passer montant à 0
        CASE
            WHEN s.nb_factures_clean = 0
                THEN 0
            WHEN s.montant_facture_unitaire_clean = 0
                AND s.montant_ht_facture_clean > 0
                AND s.nb_factures_clean > 0
                THEN s.montant_ht_facture_clean / s.nb_factures_clean
            ELSE s.montant_facture_unitaire_clean
        END AS montant_facture_unitaire,


        -- Si montant_ht_facture vide, = nb_factures * montant_facture_unitaire
        -- Si nb_factures = 0, passer montant à 0
        CASE
            WHEN s.nb_factures_clean = 0
                THEN 0
            WHEN s.montant_ht_facture_clean = 0
                AND s.nb_factures_clean > 0
                AND s.montant_facture_unitaire_clean > 0
                THEN s.nb_factures_clean * s.montant_facture_unitaire_clean
            ELSE s.montant_ht_facture_clean
        END AS montant_ht_facture


    from factures AS s
    left join complete AS c
        ON s.nom_du_projet = c.nom_du_projet
        AND (s.date_concert = c.date_concert OR c.date_concert IS NULL)

    WHERE s.date_concert BETWEEN '2024-01-01' AND '2026-06-01'
    AND s.h_1er_set IS NOT NULL
    AND s.h_1er_set > '14:30:00'

)

select * from renamed