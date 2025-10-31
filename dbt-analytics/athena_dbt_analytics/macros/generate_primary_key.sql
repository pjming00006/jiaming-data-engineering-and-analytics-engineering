{% macro generate_primary_key(hashing_columns) %}
    TO_HEX(
        MD5(
            CAST(CONCAT_WS(
                '|', 
                
                {%- for col in hashing_columns -%}
                    {%- if not loop.first -%}
                    ,
                    {%- endif -%}
                    CAST({{ col }} AS VARCHAR)
                {%- endfor -%}

            ) AS VARBINARY)))
{% endmacro %}