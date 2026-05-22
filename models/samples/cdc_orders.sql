{{ config(
    materialized='incremental',
    unique_key='order_key'
) }}

-- CDC sample model: only load rows that are new or updated since the last run.
-- In a real CDC pipeline, source data would include a true updated timestamp
-- and a delete flag. Here we use order_date as a stand-in for update tracking.

with source_data as (
    select
        o_orderkey as order_key,
        o_custkey as customer_key,
        o_orderstatus as status_code,
        o_totalprice as total_price,
        o_orderdate as order_date,
        o_orderdate as updated_at,
        false as is_deleted
    from {{ source('tpch', 'orders') }}
)

select *
from source_data

{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
