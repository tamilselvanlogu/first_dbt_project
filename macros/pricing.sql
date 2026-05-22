{% macro discounted_amount(extended_price, discount_percentage, scale=2) %}
    ({{ extended_price }} * (1 - {{ discount_percentage }} / 100))::numeric(16, {{ scale }})
{% endmacro %}