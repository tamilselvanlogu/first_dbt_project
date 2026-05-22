{% snapshot orders_scd2 %}

{{
  config(
    target_schema='snapshots',
    unique_key='order_key',
    strategy='check',
    check_cols=['customer_key', 'status_code', 'total_price']
  )
}}

select
    o_orderkey as order_key,
    o_custkey as customer_key,
    o_orderstatus as status_code,
    o_totalprice as total_price,
    o_orderdate as order_date
from {{ source('tpch', 'orders') }}

{% endsnapshot %}
