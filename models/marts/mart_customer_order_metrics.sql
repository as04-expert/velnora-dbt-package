{{ config(materialized='table', tags=['gold', 'customer_metrics']) }}

-- Snapshot of the retained fixture orders at fixture_as_of_date.
-- Aggregate before the customer join to preserve one row per account.
with customer_orders as (
    select
        account_id,
        count(*) as order_count,
        sum(case when order_status = 'cancelled' then 1 else 0 end) as cancelled_order_count,
        sum(case when delivered_at is not null then 1 else 0 end) as delivered_order_count,
        sum(case when is_delivered_on_time = 1 then 1 else 0 end) as on_time_delivered_order_count,
        sum(case when is_delivered_on_time = 0 then 1 else 0 end) as late_delivered_order_count,
        sum(is_open_order) as pending_order_count,
        sum(is_overdue_open) as overdue_pending_order_count,
        sum(case when order_status = 'in_transit' then 1 else 0 end) as in_transit_order_count,
        sum(case when order_status <> 'cancelled' then ordered_units else 0 end) as ordered_units,
        sum(booked_value_usd_cents) as booked_value_usd_cents,
        sum(booked_cost_usd_cents) as booked_cost_usd_cents,
        sum(case when is_open_order = 1 then booked_value_usd_cents else 0 end) as pending_value_usd_cents,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date
    from {{ ref('fct_orders') }}
    where order_date <= cast('{{ var("fixture_as_of_date") }}' as date)
    group by account_id
), customer_metrics as (
    select
        a.account_id,
        a.account_name,
        a.industry,
        a.region,
        a.country_code,
        a.customer_tier,
        a.account_status,
        coalesce(o.order_count, 0) as order_count,
        coalesce(o.cancelled_order_count, 0) as cancelled_order_count,
        coalesce(o.delivered_order_count, 0) as delivered_order_count,
        coalesce(o.on_time_delivered_order_count, 0) as on_time_delivered_order_count,
        coalesce(o.late_delivered_order_count, 0) as late_delivered_order_count,
        coalesce(o.pending_order_count, 0) as pending_order_count,
        coalesce(o.overdue_pending_order_count, 0) as overdue_pending_order_count,
        coalesce(o.in_transit_order_count, 0) as in_transit_order_count,
        coalesce(o.ordered_units, 0) as ordered_units,
        coalesce(o.booked_value_usd_cents, 0) as booked_value_usd_cents,
        coalesce(o.booked_cost_usd_cents, 0) as booked_cost_usd_cents,
        coalesce(o.pending_value_usd_cents, 0) as pending_value_usd_cents,
        o.first_order_date,
        o.last_order_date,
        cast('{{ var("fixture_as_of_date") }}' as date) as as_of_date
    from {{ ref('stg_accounts') }} a
    left join customer_orders o on a.account_id = o.account_id
)
select
    *,
    order_count - cancelled_order_count as non_cancelled_order_count,
    pending_order_count - overdue_pending_order_count as not_overdue_pending_order_count,
    booked_value_usd_cents - booked_cost_usd_cents as booked_margin_usd_cents,
    round(100.0 * on_time_delivered_order_count / nullif(delivered_order_count, 0), 2) as on_time_delivery_pct,
    round(100.0 * pending_order_count / nullif(order_count, 0), 2) as pending_order_pct,
    round(1.0 * booked_value_usd_cents / nullif(order_count - cancelled_order_count, 0), 2) as average_order_value_usd_cents
from customer_metrics

