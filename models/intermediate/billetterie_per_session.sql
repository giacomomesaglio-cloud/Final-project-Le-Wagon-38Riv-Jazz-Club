SELECT *,

CONCAT(jour_fr," - ",CAST(h_debut AS STRING),IF(jam IS NULL,' - Concert',CONCAT(' - ',jam))) AS session_JHJ, --concaténer jour&heure comme identitfication de session & type de jam qd nécessaire
CONCAT(jour_fr," - ",CAST(h_debut AS STRING)) AS session_JH,
CONCAT(date_evenement," - ",creneau) AS date_creneau,
CONCAT(jour_fr," - ",creneau) AS jour_creneau,
TIMESTAMP(DATETIME(date_evenement, ts_concert), 'UTC') AS date_concert, --transformer en timestamp date_evenement et ts concert

CASE
     WHEN jam = "Late Session" THEN "Jam Session / Late Session"
     ELSE "Concert"
     END AS typologie,

FROM

(SELECT
    id, 
    spectateur_id,
    spectateur_id_source,
    heure_evenement,
    evenement,
    date_achat,
    canal_de_vente,
    montant,
    code_postal,
    ville, 
    numero_ordre,
    date_evenement,
    1 as nb_place,

    CASE
          WHEN heure_evenement BETWEEN '14:31:00' AND '16:29:00'THEN TIME '15:00:00'
          WHEN heure_evenement BETWEEN '16:30:00' AND '18:59:00'THEN TIME '17:00:00'
          WHEN heure_evenement BETWEEN '19:00:00' AND '20:59:00'THEN TIME '19:30:00'
          WHEN heure_evenement BETWEEN '21:00:00' AND '22:29:00'THEN TIME '21:30:00'
          ELSE TIME '23:00:00'
          END AS ts_concert,

    
     CASE
          WHEN heure_evenement < TIME '18:00:00' THEN 'apres_midi'
          WHEN heure_evenement < TIME '23:00:00' THEN 'soir'
          ELSE 'late_jam'
          END AS creneau,
    IF (montant > 0,'payé','invitation') AS type,
    FORMAT_TIME('%R', heure_evenement) AS h_debut, --format HH:MM
    CASE EXTRACT(DAYOFWEEK FROM date_evenement) --extraction du jour dans la date
        WHEN 1 THEN 'Dimanche'
        WHEN 2 THEN 'Lundi'
        WHEN 3 THEN 'Mardi'
        WHEN 4 THEN 'Mercredi'
        WHEN 5 THEN 'Jeudi'
        WHEN 6 THEN 'Vendredi'
        WHEN 7 THEN 'Samedi'
    END AS jour_fr,



--creation d'une catégorie "jam" pour ajouter ce détail dans la colonne session_JH qd nécessaire en fonction du créneau horaire 

        CASE 
           --Mardi
            WHEN EXTRACT(DAYOFWEEK FROM date_evenement) = 3
                 AND EXTRACT(HOUR FROM heure_evenement) = 23
            THEN 'Jam Funk'

           --Mercredi
            WHEN EXTRACT(DAYOFWEEK FROM date_evenement) = 4
                 AND EXTRACT(HOUR FROM heure_evenement) = 23
            THEN 'Jam Jazz'

           --Jeudi
            WHEN EXTRACT(DAYOFWEEK FROM date_evenement) = 5
                 AND EXTRACT(HOUR FROM heure_evenement) = 23
            THEN 'Jam Jazz'

           --Vendredi 23:59
            WHEN EXTRACT(DAYOFWEEK FROM date_evenement) = 6
                 AND heure_evenement = TIME '23:59:00'
            THEN 'Jam Groove' 

           --Vendredi 23:00 à 23:58 
            WHEN EXTRACT(DAYOFWEEK FROM date_evenement) = 6
                 AND EXTRACT(HOUR FROM heure_evenement) = 23
            THEN 'Late Session'

           --Samedi 23:59
            WHEN EXTRACT(DAYOFWEEK FROM date_evenement) = 7
                 AND heure_evenement = TIME '23:59:00'
            THEN 'Jam Jazz'  
           
           --Samedi 23/00 à 23:58
            WHEN EXTRACT(DAYOFWEEK FROM date_evenement) = 7
                 AND EXTRACT(HOUR FROM heure_evenement) = 23
            THEN 'Late Session'

          

            ELSE NULL
        END AS jam




FROM {{ ref('stg_raw_data_38__billetterie_') }})

WHERE date_evenement BETWEEN '2024-01-01' AND '2026-05-31'


