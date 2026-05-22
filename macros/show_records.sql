{% macro show_records(relation, limit=20) %}
{% set sql %}
    select * from {{ relation }} limit {{ limit }}
{% endset %}

{% set results = run_query(sql) %}

{% if execute %}
    {% if results is none %}
        {{ log('No results returned from query.', info=True) }}
    {% else %}
        {% for row in results %}
            {{ log(row.values() | join(', '), info=True) }}
        {% endfor %}
    {% endif %}
{% endif %}
{% endmacro %}
