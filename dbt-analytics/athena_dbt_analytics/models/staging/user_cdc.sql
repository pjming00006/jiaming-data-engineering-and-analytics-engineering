SELECT
    TO_HEX(MD5(CAST(CONCAT_WS(' ', CAST(user_id AS VARCHAR), CAST(processing_timestamp AS VARCHAR)) AS VARBINARY)))  AS user_cdc_id
    , CAST(user_id AS VARCHAR)                                                                                       AS user_id
    , CAST(cdc_type AS VARCHAR)                                                                                      AS event_type
    , CAST(JSON_EXTRACT(JSON_PARSE(user_attributes), '$.partner_id') AS INT)                                         AS partner_id
    , CAST(JSON_EXTRACT(JSON_PARSE(user_attributes), '$.program_id') AS INT)                                         AS program_id
    , CAST(CAST(JSON_EXTRACT(JSON_PARSE(user_attributes), '$.program_start_date') AS VARCHAR) AS DATE)               AS program_start_date
    , CAST(JSON_EXTRACT(JSON_PARSE(user_attributes), '$.client_name') AS VARCHAR)                                    AS client_name
    , CAST("$path" AS VARCHAR)                                                                                       AS file_path
    , CAST(processing_timestamp AS TIMESTAMP)                                                                        AS updated_at
    , CAST(CURRENT_TIMESTAMP AS TIMESTAMP)                                                                           AS loaded_at
FROM 
    {{ source('dbt-analytics', 'dynamo_lambda_firehose_s3_etl_parquet') }}
{% if is_incremental() %}
WHERE CAST(processing_timestamp AS TIMESTAMP) > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}