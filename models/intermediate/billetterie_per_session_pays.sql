
--  creation de deux colonnes:  score_m (score meteo en fonction de vent FFM,pluie RR,temp_moyenne TM), score_ensoleillement (en fonction de INST = l'ensoleillement)

-- Principe : chaque paramètre brut est converti en score 0-3 sur sa propre échelle, puis les scores sont additionnés.
-- Les unités (°C*10, m/s*10, mm*10) disparaissent à l'étape de conversion — on additionne des points homogènes, pas des valeurs brutes.

-- Exemple:
--   TM  185 (=18,5°C)  → zone confort       → 3 pts
--   FFM  55 (=5,5 m/s) → légère brise       → 2 pts
--   RR    0 (=0 mm)    → pas de pluie       → 3 pts
--   Total                                   → 8/9 → m_optimal



WITH meteo_scored AS (


  -- STEP 1 : conversion de chaque paramètre brut en score
  -- On retient uniquement TM (et non TN/TX) car TM synthétise déjà le confort thermique de la journée 
  -- 3 paramètres retenus × 3 pts max = 9 pts max au total



  SELECT
    date_formatee,
    rr, tm, ffm, inst,

    -- TM : confort thermique global de la journée
    -- Valeurs brutes en °C * 10 (ex: 185 = 18,5°C)
    -- Zone de confort pour sortir : 15-22°C (150-220 en brut)


    CASE
      WHEN tm BETWEEN 150 AND 220                           THEN 3  -- confort optimal
      WHEN tm BETWEEN 100 AND 149 OR tm BETWEEN 221 AND 270 THEN 2  -- légère gêne thermique
      WHEN tm BETWEEN  50 AND  99 OR tm BETWEEN 271 AND 330 THEN 1  -- froid ou chaud notable
      ELSE 0                                                         -- température extrême
    END AS score_tm,

    -- FFM : dissuasion au déplacement (vent moyen)
    -- Valeurs brutes en m/s * 10 (ex: 42 ≈ 4,2 m/s ≈ 15 km/h)
    -- Le vent est plus dissuasif que le froid seul


    CASE
      WHEN ffm <  42               THEN 3  -- < 15 km/h : imperceptible
      WHEN ffm BETWEEN  42 AND  83 THEN 2  -- 15-30 km/h : brise légère
      WHEN ffm BETWEEN  84 AND 139 THEN 1  -- 30-50 km/h : vent notable
      ELSE 0                               -- > 50 km/h : vent fort
    END AS score_ffm,



    -- RR : frein le plus direct à la décision de sortir
    -- Valeurs brutes en mm * 10 (ex: 20 = 2 mm)

    CASE
      WHEN rr = 0                 THEN 3  -- pas de pluie
      WHEN rr BETWEEN   1 AND  20 THEN 2  -- bruine légère (< 2 mm), peu dissuasive
      WHEN rr BETWEEN  21 AND 100 THEN 1  -- pluie modérée (2-10 mm)
      ELSE 0                              -- pluie forte (> 10 mm), impact fort
    END AS score_rr,


    -- INST : score ensoleillement — colonne indépendante du score météo
    -- Valeur directe en minutes

    CASE
      WHEN inst BETWEEN 240 AND 420 THEN 'soleil_optimal'   -- 4h-7h 
      WHEN inst >  420              THEN 'soleil_excessif'   -- > 7h  
      WHEN inst BETWEEN  60 AND 239 THEN 'soleil_faible'     -- 1h-4h 
      ELSE                               'soleil_absent'     -- < 1h  
    END AS score_ensoleillement

  FROM {{ ref('stg_raw_data_38__paris_montsouris_2024_2025_05_2026') }}
  WHERE date_formatee BETWEEN '2024-01-01' AND '2026-05-31'  -- aligné sur le filtre billetterie_per_session pcq meteo scored lis la table meteo raw direct

),


meteo_categorized AS (


  -- STEP 2 : agrégation des scores et attribution de la catégorie

  -- score_m = score_tm + score_ffm + score_rr (max 9 pts)

  --   m_optimal  ≥ 8 pts : les 3 paramètres bons simultanément
  --   m_correct  5-7 pts : 1 paramètre imparfait, les 2 autres compensent
  --   m_mediocre 2-4 pts : au moins 2 paramètres défavorables
  --   m_mauvais  ≤ 1 pt  : quasi tout mauvais (froid + vent + pluie)



  SELECT
    *,
    CASE
      WHEN (score_tm + score_ffm + score_rr) >= 8 THEN 'm_optimal'
      WHEN (score_tm + score_ffm + score_rr) >= 5 THEN 'm_correct'
      WHEN (score_tm + score_ffm + score_rr) >= 2 THEN 'm_mediocre'
      ELSE 'm_mauvais'
    END AS score_m

  FROM meteo_scored
),


meteo_labeled AS (


  -- STEP 3 : catégorie météo finale, croisant score_m et score_ensoleillement
  -- 5 catégories : grand_froid / vent / pluie / passable / agreable / trop_chaud

  -- Ordre de priorité :
  --   1. Extrêmes thermiques (tm brut) — écrasent tout
  --   2. Vent fort (score_ffm = 0) — dissuasif indépendamment du reste
  --   3. Trop chaud via ensoleillement excessif
  --   4. Pluie — météo dégradée sans lumière pour compenser
  --   5. Agréable — bon score + lumière suffisante
  --   6. Passable — tout le reste



  SELECT
    *,
    CASE
      -- Extrêmes thermiques : priorité absolue sur tout le reste
      WHEN tm <= 50                                                       THEN 'grand_froid'  -- ≤ 5°C
      WHEN tm >= 300                                                      THEN 'trop_chaud'   -- ≥ 30°C

      -- Vent fort : score FFM nul, dissuasif indépendamment de la météo globale
      WHEN score_ffm = 0                                                  THEN 'vent'         -- > 50 km/h

      -- Trop chaud via ensoleillement excessif (hors grand froid déjà traité)
      WHEN score_ensoleillement = 'soleil_excessif'
       AND score_m IN ('m_optimal', 'm_correct')                         THEN 'trop_chaud'

      -- Pluie : météo dégradée sans lumière pour compenser
      WHEN score_m = 'm_mauvais'                                          THEN 'pluie'
      WHEN score_m = 'm_mediocre'
       AND score_ensoleillement = 'soleil_absent'                         THEN 'pluie'

      -- Agréable : bon score + lumière suffisante
      WHEN score_m = 'm_optimal'
       AND score_ensoleillement IN ('soleil_faible', 'soleil_optimal')    THEN 'agreable'
      WHEN score_m = 'm_correct'
       AND score_ensoleillement = 'soleil_optimal'                        THEN 'agreable'

      -- Passable : tout le reste
      ELSE                                                                 'passable'
    END AS meteo

  FROM meteo_categorized

)



-- SELECT FINAL : jointure billetterie + ville + météo scorée



SELECT
  b.id,
  b.spectateur_id,
  b.spectateur_id_source,
  b.heure_evenement,
  b.evenement,
  b.date_achat,
  b.canal_de_vente,
  CASE 
    WHEN canal_de_vente LIKE 'Au guichet%' THEN 1
    ELSE 0
    END AS vente_guichet,
  b.montant, -- prix d'achat du billet
  CASE 
    WHEN b.montant = MAX(b.montant) OVER (PARTITION BY b.evenement) THEN 1 
    ELSE 0 
  END AS plein_tarif_flag,
  CASE 
    WHEN b.montant > 0 
     AND b.montant < MAX(b.montant) OVER (PARTITION BY b.evenement) THEN 1 
    ELSE 0 
  END AS tarif_reduit_flag,
  b.code_postal,
  b.ville,
  b.numero_ordre,
  b.nb_place,
  b.ts_concert,
  b.creneau,
  b.type,
  CASE 
    WHEN b.type = 'invitation' THEN 1
    ELSE 0
    END AS invitation,
  b.h_debut,
  b.jour_fr,
  b.jam,
  b.session_JHJ,
  b.session_JH,
  b.date_creneau,
  b.jour_creneau,
  b.date_concert,
  b.typologie,
  b.date_evenement  AS date_,      -- renommée date_ pour éviter le doublon avec la CTE
  meteo.rr          AS precipitations,
  meteo.tm          AS temp_moy,
  meteo.ffm         AS vent_moy,
  meteo.inst        AS duree_insolation,
  meteo.score_m,                   -- catégorie météo globale : m_optimal / m_correct / m_mediocre / m_mauvais
  meteo.score_ensoleillement,      -- catégorie soleil : soleil_optimal / soleil_excessif / soleil_faible / soleil_absent
  meteo.meteo,                     -- catégorie finale : grand_froid / vent / pluie / passable / agreable / trop_chaud
  IFNULL(v.pays,      'NA') AS pays,
  IFNULL(v.continent, 'NA') AS continent

FROM {{ ref('billetterie_per_session') }} AS b

LEFT JOIN ( -- Dédoublonnage de la table de référence ville/pays/continent
  SELECT DISTINCT ville, code_postal, pays, continent
  FROM {{ ref('stg_raw_data_38__code_ville_pays_continent') }}
) AS v
ON b.ville = v.ville AND b.code_postal = v.code_postal

-- Jointure sur la CTE meteo_labeled (et non la table brute pour pouvoir récupérer toutes les colonnes calculées en amont)
-- pour récupérer score_m, score_ensoleillement et meteo calculés en amont

LEFT JOIN meteo_labeled AS meteo
ON b.date_evenement = meteo.date_formatee