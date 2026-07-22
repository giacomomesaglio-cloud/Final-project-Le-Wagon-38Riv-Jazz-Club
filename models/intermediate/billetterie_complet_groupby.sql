SELECT 
date_concert
,evenement AS nom_du_projet
,MAX(montant) AS plein_tarif
,ROUND(AVG(montant), 2) AS tarif_moyen
,ROUND(SUM(plein_tarif_flag) / SUM(nb_place) * 100, 2) AS pct_plein_tarif
,ROUND(SUM(tarif_reduit_flag) / SUM(nb_place) * 100, 2) AS pct_tarif_reduit
,SUM(montant) AS recettes_billetterie 
,SUM(nb_place) AS tot_places_vendues
,ROUND(SUM(nb_place) / 41 *100, 2) AS tx_remplissage
,ROUND (SUM(vente_guichet) / SUM(nb_place) * 100, 2) AS pct_guichet
,ROUND(100 - (SUM(vente_guichet) / SUM(nb_place) * 100), 2) AS pct_web
,ROUND (SUM(invitation) / SUM(nb_place) * 100, 2) AS pct_invitation
,ROUND(100 - (SUM(invitation) / SUM(nb_place) * 100), 2) AS pct_payed
,creneau
,session_JHJ
,session_JH
,date_creneau
,jour_creneau
,jour_fr
,typologie
,AVG(precipitations) AS precipitations
,AVG(temp_moy) AS temp_moy
,AVG(vent_moy) AS vent_moy
,AVG(duree_insolation) AS duree_insolation
,score_m
,score_ensoleillement
,meteo
FROM {{ ref('billetterie_per_session_pays') }}
GROUP BY date_concert, evenement, creneau, session_JHJ, session_JH, date_creneau, typologie, score_m, score_ensoleillement, meteo, jour_creneau, jour_fr








