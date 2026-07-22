WITH subquerie AS (
    SELECT
    *,
        CASE
            WHEN date_creneau IN ('lundi - late_jam', 'mardi - late_jam', 'mercredi - late_jam','jeudi - late_jam', 'vendredi - late_jam', 'samedi - late_jam') 
            THEN ROUND(120 * (1+0.1*(EXTRACT(YEAR FROM date_concert) -2026)),2)
            WHEN date_creneau IN ('dimanche - apres_midi', 'dimanche - soir', 'lundi - soir')
            THEN ROUND(189/2 * (1+0.1*(EXTRACT(YEAR FROM date_concert) -2026)),2) -- Division par 2 pour prendre en compte la présence des deux créneaux et modulation par année pour prendre en compte les dynamiques salariales
            WHEN session_JH IN ('Samedi - 10:30', 'Samedi - 14:00', 'Samedi - 15:00')
            THEN ROUND(189/2 *(1+0.1*(EXTRACT(YEAR FROM date_concert) -2026)),2) -- Division par 2 pour prendre en compte la présence des deux créneaux et modulation par année pour prendre en compte les dynamiques salariales
            ELSE ROUND(252/2 * (1+0.1*(EXTRACT(YEAR FROM date_concert) -2026)),2) -- Division par 2 pour prendre en compte la présence des deux créneaux et modulation par année pour prendre en compte les dynamiques salariales
        END AS charges_personnel,

--Cachets fixes / forfaits en euros: 'Jam' = 250/nb personnes JAM  — 'dimanche 15:00' OU samedi 15:00' = 400 — SINON 800 
        CASE
            WHEN date_creneau IN ('lundi - late_jam', 'mardi - late_jam', 'mercredi - late_jam','jeudi - late_jam', 'vendredi - late_jam', 'samedi - late_jam')
            THEN 220
            WHEN date_creneau IN ('dimanche - apres_midi', 'samedi - apres_midi')
            THEN 350/2 -- Division par 2 pour prendre en compte la présence des deux créneaux et modulation par année pour prendre en compte les dynamiques salariales
            ELSE 720/2 -- Division par 2 pour prendre en compte la présence des deux créneaux et modulation par année pour prendre en compte les dynamiques salariales
        END AS charges_fixes_vAE,

-- Charges artistiques :
-- Late jam → uniquement montant_jam (les autres champs sont null par nature)
-- Doublon → moyenne des deux créneaux (division par 2)
-- Sinon → somme complète des composantes artistiques
CASE 
    WHEN date_creneau IN ('lundi - late_jam', 'mardi - late_jam', 'mercredi - late_jam',
                          'jeudi - late_jam', 'vendredi - late_jam', 'samedi - late_jam')
    THEN COALESCE(montant_jam, 0)

    WHEN doublon_charges_artistiques = "Doublon" 
    THEN ROUND(
        (
            (COALESCE(nb_cachet, 0) * COALESCE(montant_cachet_unitaire, 0) * 2)  {# cachets × 2 pour le coût employer #}
            + COALESCE(montant_cession, 0)
            + COALESCE(montant_ht_facture, 0)
            + COALESCE(montant_corea, 0)
            + COALESCE(montant_jam, 0)
        ) / 2,  {# division par 2 : doublon = deux créneaux partagent la même charge #}
    2)

    ELSE ROUND(
        (COALESCE(nb_cachet, 0) * COALESCE(montant_cachet_unitaire, 0) * 2)  {# cachets × 2 musiciens #}
        + COALESCE(montant_cession, 0)
        + COALESCE(montant_ht_facture, 0)
        + COALESCE(montant_corea, 0)
        + COALESCE(montant_jam, 0),
    2)
END AS charges_artistiques,

EXTRACT(YEAR FROM date_concert) 
AS year --- extraction de l'année pour moduler les charges


    FROM {{ ref('main_table') }}
)


SELECT
*,

ROUND((recettes_billetterie - charges_artistiques),2) 
AS marge_brute_billetterie,

ROUND((recettes_bar*0.7),2) 
AS marge_brute_bar,

ROUND((recettes_billetterie - charges_artistiques) - (charges_personnel / 3) - 0.09 * recettes_billetterie,2) 
AS marge_nette_billetterie,

ROUND((recettes_bar * 0.7) - ((charges_personnel * 2) / 3), 2) 
AS marge_nette_bar,

ROUND(recettes_bar / tot_places_vendues,2) AS panier_moyen_bar,

--ROUND((520 / nb_concert_par_jour + recettes_billetterie *0.075),2) 
ROUND(charges_fixes_vAE,2)-50*(2026-year) --- modulation des charges fixes selon l'année, hypothèses d'augmentation des charges fixes de 50€ par an
AS charges_fixes,

ROUND((recettes_billetterie - charges_artistiques) + (recettes_bar*0.7) - charges_personnel - 0.095*recettes_billetterie,2) 
AS marge_par_couts_variables,


ROUND((recettes_billetterie - charges_artistiques) + (recettes_bar*0.7) - charges_personnel - 0.095*recettes_billetterie - charges_fixes_vAE,2) 
AS marge

FROM subquerie