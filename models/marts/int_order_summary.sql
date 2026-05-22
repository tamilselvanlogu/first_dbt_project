{{config(
    materialized='table'
)}}

select 
    order_key,
    sum(extended_price) as gross_item_sales_amount,
    sum(discounted_price) as item_discount_amount
from {{ ref('int_order_items_summary') }}
group by order_key