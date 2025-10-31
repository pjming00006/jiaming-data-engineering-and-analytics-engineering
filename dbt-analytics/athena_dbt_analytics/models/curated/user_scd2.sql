/*
For incremental runs, there are 2 scenarios
1. New user record: process the record by itself, marking it as current
2. An existing user record update: 
    a. Need to pull the most recent record for that user, mark is_current = false, and change record_end_effective_at to updated_at of new record
    b. Process the new record and mark it as current

Things to look out:
1. In an incremental update, the same user might have multiple updates from source. Therefore a re-rank is necessary
*/

{% if is_incremental() %}
-- Select records landed in staging since last run
WITH incremental_users AS (
    SELECT
        user_id
        , event_type
        , partner_id
        , program_id
        , program_start_date
        , client_name
        , file_path
        , updated_at
    FROM {{ ref('user_cdc') }}
    WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
)
-- Select incremental records and union with the current records where user has update
, user_demographics AS (
    SELECT
        *
    FROM incremental_users incr

    UNION ALL 

    SELECT
        user_id
        , event_type
        , partner_id
        , program_id
        , program_start_date
        , client_name
        , file_path
        , updated_at
    FROM {{ this }} curr
    INNER JOIN (SELECT DISTINCT user_id FROM incremental_users) USING (user_id)
    WHERE 
        curr.is_current = true
)

, user_rk AS (
{% else %}

WITH user_rk AS (
{% endif %}
    -- Window function to calculate ranges and ranks
    SELECT
        user_id
        , event_type
        , partner_id
        , program_id
        , program_start_date
        , client_name
        , updated_at                               AS valid_from
        , COALESCE(LEAD(updated_at) 
            OVER(PARTITION BY user_id 
                 ORDER BY updated_at ASC)
            , CAST('9999-12-31' AS TIMESTAMP))     AS valid_to
        , ROW_NUMBER() 
            OVER(PARTITION BY user_id 
                 ORDER BY updated_at DESC)         AS rk
        , file_path
        , updated_at
    {% if is_incremental() %}
    FROM user_demographics
    {% else %}
    FROM {{ ref('user_cdc') }}
    {% endif %}
)
-- PK represents the correct grain: id and timestamp
SELECT
    {{ generate_primary_key(['user_id', 'valid_from']) }}                AS user_scd2_id
    , user_id
    , event_type
    , partner_id
    , program_id
    , program_start_date
    , client_name
    , valid_from                                                         AS valid_from
    , valid_to                                                           AS valid_to
    , CAST(CASE WHEN rk = 1 THEN true ELSE false END AS BOOLEAN)         AS is_current
    , file_path
    , updated_at
    , CAST(CURRENT_TIMESTAMP AS TIMESTAMP)                               AS loaded_at
FROM user_rk