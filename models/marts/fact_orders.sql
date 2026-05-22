{{config(
    materialized='table'
)}}

select 
    orders.*,
    items.gross_item_sales_amount,
    items.item_discount_amount
from {{ ref('stg_tpch_orders') }} orders
join {{ ref('int_order_summary') }} items
    on orders.order_key = items.order_key
