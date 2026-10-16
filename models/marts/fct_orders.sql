with item_totals as (
    select order_id, sum(quantity) as ordered_units,
           sum(line_net_usd_cents) as booked_value_usd_cents,
           sum(quantity * unit_cost_usd_cents) as booked_cost_usd_cents
    from {{ ref('stg_order_items') }} group by order_id
), ranked_events as (
    select *, row_number() over (
        partition by order_id order by event_occurred_at desc, event_id desc
    ) as latest_event_rank
    from {{ ref('stg_carrier_events') }}
), deliveries as (
    select order_id, min(event_occurred_at) as delivered_at
    from {{ ref('stg_carrier_events') }} where event_status = 'delivered' group by order_id
)
select o.order_id, o.account_id, a.account_name, a.industry, a.region,
       h.customer_tier as customer_tier_at_order, h.payment_terms_days as payment_terms_days_at_order,
       o.order_date, o.ordered_at, o.promised_delivery_date, o.order_status, o.currency_code,
       i.ordered_units,
       case when o.order_status = 'cancelled' then 0 else i.booked_value_usd_cents end as booked_value_usd_cents,
       case when o.order_status = 'cancelled' then 0 else i.booked_cost_usd_cents end as booked_cost_usd_cents,
       coalesce(e.event_status, case when o.order_status = 'cancelled' then 'cancelled' else 'not_shipped' end) as latest_carrier_status,
       e.raw_event_status as latest_raw_carrier_status, d.delivered_at,
       case when d.delivered_at is not null and cast(d.delivered_at as date) <= o.promised_delivery_date then 1
            when d.delivered_at is not null then 0 else null end as is_delivered_on_time,
       case when o.order_status <> 'cancelled' and d.delivered_at is null
                 and o.promised_delivery_date < cast('{{ var("fixture_as_of_date") }}' as date)
            then 1 else 0 end as is_overdue_open
from {{ ref('stg_orders') }} o
join {{ ref('stg_accounts') }} a on o.account_id = a.account_id
join item_totals i on o.order_id = i.order_id
left join ranked_events e on o.order_id = e.order_id and e.latest_event_rank = 1
left join deliveries d on o.order_id = d.order_id
left join {{ ref('dim_account_history') }} h on o.account_id = h.account_id
    and o.ordered_at >= h.valid_from and (o.ordered_at < h.valid_to or h.valid_to is null)
