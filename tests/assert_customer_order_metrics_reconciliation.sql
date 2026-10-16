{{ config(severity='error', tags=['customer_metrics']) }}

-- Reconcile each customer's mart totals to the order headers and fact independently.
with header_counts as (
    select account_id, count(*) as order_count
    from {{ ref('stg_orders') }}
    where order_date <= cast('{{ var("fixture_as_of_date") }}' as date)
    group by account_id
), fact_totals as (
    select account_id,
           sum(booked_value_usd_cents) as booked_value_usd_cents,
           sum(booked_cost_usd_cents) as booked_cost_usd_cents
    from {{ ref('fct_orders') }}
    where order_date <= cast('{{ var("fixture_as_of_date") }}' as date)
    group by account_id
)
select m.account_id
from {{ ref('mart_customer_order_metrics') }} m
left join header_counts h on m.account_id = h.account_id
left join fact_totals f on m.account_id = f.account_id
where m.order_count <> coalesce(h.order_count, 0)
   or m.booked_value_usd_cents <> coalesce(f.booked_value_usd_cents, 0)
   or m.booked_cost_usd_cents <> coalesce(f.booked_cost_usd_cents, 0)

