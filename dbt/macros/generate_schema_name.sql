{#
  Use custom schema names as-is instead of dbt's default
  "<target_schema>_<custom_schema>" concatenation.

  With this override, a model configured `+schema: marts` lands in
  OLIST.MARTS (not OLIST.STG_MARTS), matching docs/star_schema.md and
  the sql_highlights/ queries.
#}

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
