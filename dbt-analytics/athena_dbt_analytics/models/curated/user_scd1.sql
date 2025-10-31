WITH latest_user AS (
    SELECT
        *
        , ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY updated_at DESC) AS rk
    FROM {{ ref('user_cdc') }}
)

SELECT
    user_id
    , event_type
    , partner_id
    , program_id
    , program_start_date
    , client_name
    , updated_at
    , CAST(CURRENT_TIMESTAMP AS TIMESTAMP) AS loaded_at
FROM latest_user
WHERE rk = 1