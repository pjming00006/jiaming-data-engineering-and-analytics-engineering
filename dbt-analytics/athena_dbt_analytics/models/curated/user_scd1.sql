WITH latest_user AS (
    SELECT
        *
        , ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY updated_at DESC) AS rk
    FROM {{ ref('user_cdc') }}
    {% if is_incremental() %}
    WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
    {% endif %}
)

SELECT
    {{ generate_primary_key(['user_id']) }}  AS user_scd1_id
    , user_id
    , event_type
    , partner_id
    , program_id
    , program_start_date
    , client_name
    , file_path
    , updated_at
    , CAST(CURRENT_TIMESTAMP AS TIMESTAMP)   AS loaded_at
FROM latest_user
WHERE rk = 1