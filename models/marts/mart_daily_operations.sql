with requested_returns as (
    select i.order_id, sum(r.quantity) as return_requested_units,
           sum(case when r.return_status = 'credited' then r.credit_amount_usd_cents else 0 end) as issued_return_credits_usd_cents
    from {{ ref('raw_return_events') }} r
    join {{ ref('stg_order_items') }} i on r.order_item_id = i.order_item_id
    where cast(cast(r.requested_at as timestamp) as date) <= cast('{{ var("fixture_as_of_date") }}' as date)
    group by i.order_id
)
select f.order_date, count(*) as order_count,
       sum(case when f.order_status = 'cancelled' then 1 else 0 end) as cancelled_order_count,
       sum(f.booked_value_usd_cents) as booked_value_usd_cents,
       sum(f.booked_cost_usd_cents) as booked_cost_usd_cents,
       sum(case when f.delivered_at is not null then 1 else 0 end) as delivered_order_count,
       sum(case when f.is_delivered_on_time = 1 then 1 else 0 end) as on_time_delivered_order_count,
       sum(f.is_overdue_open) as overdue_open_order_count,
       sum(coalesce(r.return_requested_units,0)) as return_requested_units,
       sum(coalesce(r.issued_return_credits_usd_cents,0)) as issued_return_credits_usd_cents,
       cast('{{ var("fixture_as_of_date") }}' as date) as as_of_date
from {{ ref('fct_orders') }} f
left join requested_returns r on f.order_id = r.order_id
group by f.order_date
