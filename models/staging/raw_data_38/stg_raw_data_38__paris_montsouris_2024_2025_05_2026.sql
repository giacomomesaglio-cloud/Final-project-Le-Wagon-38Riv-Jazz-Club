with 

source as (

    select * from {{ source('raw_data_38', 'paris_montsouris_2024_2025_05_2026') }}

),

renamed as (

    select
        PARSE_DATE('%Y%m%d', CAST(date AS STRING)) AS date_formatee,
        rr,
        tn,
        tx,
        tm,
        inst,
        ffm



    from source

)

select * from renamed