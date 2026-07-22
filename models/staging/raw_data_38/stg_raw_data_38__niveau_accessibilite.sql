with 

source as (

    select * from {{ source('raw_data_38', 'niveau_accessibilite') }}

),

renamed as (

    select
        id,
        nom_du_projet,
        date_concert,
        heure_1er_set,
        heure_2e_set,
        sous_titre,
        artiste_lead,
        sexe_artiste_lead,
        formation,
        lineup,
        tarifs,
        statut_mise_en_ligne,
        conditions,
        nb_cachets,
        montant_cachet_unitaire,
        montant_cession,
        nb_factures,
        montant_facture_unitaire,
        defraiements,
        commentaires,
        source_donnee,
        montant_ht_facture,
        montant_ttc_facture,
        accessibilite_score,
        accessibilite_confidence

    from source

)

select * from renamed