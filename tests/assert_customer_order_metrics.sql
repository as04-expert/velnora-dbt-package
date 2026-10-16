{{ config(severity='error', tags=['customer_metrics']) }}

with metrics as (
    select * from {{ ref('mart_customer_order_metrics') }}
), violations as (
    select 'customer_coverage' as rule, a.account_id
    from {{ ref('stg_accounts') }} a
    left join metrics m on a.account_id = m.account_id
    where m.account_id is null
    union all
    select 'order_partition', account_id from metrics
    where order_count <> delivered_order_count + pending_order_count + cancelled_order_count
       or delivered_order_count <> on_time_delivered_order_count + late_delivered_order_count
       or pending_order_count <> overdue_pending_order_count + not_overdue_pending_order_count
       or overdue_pending_order_count < 0 or not_overdue_pending_order_count < 0
       or in_transit_order_count > pending_order_count
    union all
    select 'percentage_bounds', account_id from metrics
    where on_time_delivery_pct < 0 or on_time_delivery_pct > 100
       or pending_order_pct < 0 or pending_order_pct > 100
       or (delivered_order_count = 0 and on_time_delivery_pct is not null)
       or (delivered_order_count > 0 and on_time_delivery_pct is null)
    union all
    select 'zero_order_customer', account_id from metrics
    where order_count = 0 and (
        booked_value_usd_cents <> 0 or pending_order_count <> 0
        or first_order_date is not null or last_order_date is not null
        or on_time_delivery_pct is not null or average_order_value_usd_cents is not null
    )
    union all
    select 'orphan_order', o.account_id
    from {{ ref('fct_orders') }} o
    left join {{ ref('stg_accounts') }} a on o.account_id = a.account_id
    where a.account_id is null
    union all
    select 'unsupported_order_state', account_id
    from {{ ref('fct_orders') }}
    where order_status not in ('confirmed', 'processing', 'in_transit', 'fulfilled', 'cancelled')
       or order_status is null or currency_code <> 'USD' or currency_code is null
       or is_open_order is null or is_overdue_open is null
       or (delivered_at is not null and (is_delivered_on_time is null or is_open_order = 1))
       or cast(delivered_at as date) > cast('{{ var("fixture_as_of_date") }}' as date)
)
select * from violations

