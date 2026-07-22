with 

source as (

    select * from {{ source('raw_data_38', 'code_ville_pays_continent') }}

),

renamed as (

    select
        ville,
        code_postal,
        pays,
        continent

    from source

)

select * from renamed