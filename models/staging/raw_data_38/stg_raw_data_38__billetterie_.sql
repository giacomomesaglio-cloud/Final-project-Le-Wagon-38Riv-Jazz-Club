with 

source as (

    select * from {{ source('raw_data_38', 'billetterie_') }}

),

renamed as (

    select
        id,
        FORMAT_DATETIME('%Y-%m-%d %H:%M:%S', DATETIME(date_evenement, heure_evenement)) as datetime_evenement,
        spectateur_id,
        spectateur_id_source,
        date_evenement,
        heure_evenement,
        evenement,
        date_achat,
        canal_de_vente,
        moyen_de_paiement,
        tarif,
        montant,
        type_abonnement,
        numero_ordre,
        id_abonne,
        categorie,
        gamme,
        contingent,
        code_postal,
        ville,
        created_at

    from source

)

SELECT *
from renamed