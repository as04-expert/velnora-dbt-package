{{ config(severity='error', tags=['core_quality'], store_failures=true) }}
-- Seed-level contract deliberately independent of both incident branches.
with accounts as (select * from {{ ref('raw_accounts') }}),
orders as (select * from {{ ref('raw_orders') }}),
items as (select * from {{ ref('raw_order_items') }}),
events as (select * from {{ ref('raw_carrier_events') }}),
invoices as (select * from {{ ref('raw_invoice_lines') }}),
returns as (select * from {{ ref('raw_return_events') }}),
changes as (select * from {{ ref('raw_account_changes') }}),
violations as (
    select 'account_key' as rule, account_id as record_id from accounts group by account_id having count(*)<>1 or account_id is null
    union all select 'order_key', order_id from orders group by order_id having count(*)<>1 or order_id is null
    union all select 'item_key', order_item_id from items group by order_item_id having count(*)<>1 or order_item_id is null
    union all select 'event_ingestion_key', ingestion_row_id from events group by ingestion_row_id having count(*)<>1 or ingestion_row_id is null
    union all select 'invoice_ingestion_key', ingestion_row_id from invoices group by ingestion_row_id having count(*)<>1 or ingestion_row_id is null
    union all select 'return_key', return_event_id from returns group by return_event_id having count(*)<>1 or return_event_id is null
    union all select 'change_key', change_id from changes group by change_id having count(*)<>1 or change_id is null
    union all select 'order_account_fk', o.order_id from orders o left join accounts a on o.account_id=a.account_id where a.account_id is null
    union all select 'item_order_fk', i.order_item_id from items i left join orders o on i.order_id=o.order_id where o.order_id is null
    union all select 'event_order_fk', e.ingestion_row_id from events e left join orders o on e.order_id=o.order_id where o.order_id is null
    union all select 'invoice_item_fk', v.ingestion_row_id from invoices v left join items i on v.order_item_id=i.order_item_id where i.order_item_id is null or v.order_id<>i.order_id
    union all select 'return_item_fk', r.return_event_id from returns r left join items i on r.order_item_id=i.order_item_id where i.order_item_id is null or r.quantity>i.quantity
    union all select 'change_account_fk', c.change_id from changes c left join accounts a on c.account_id=a.account_id where a.account_id is null
    union all select 'line_arithmetic', order_item_id from items where quantity<=0 or unit_price_usd_cents<=0 or unit_cost_usd_cents<=0 or line_net_usd_cents<>quantity*unit_price_usd_cents-line_discount_usd_cents or line_discount_usd_cents<0 or line_net_usd_cents<0 or currency_code<>'USD'
    union all select 'invoice_arithmetic', v.ingestion_row_id from invoices v join items i on v.order_item_id=i.order_item_id where v.quantity<>i.quantity or v.net_amount_usd_cents<>i.line_net_usd_cents or cast(v.due_date as date)<cast(v.invoice_date as date) or v.currency_code<>'USD'
    union all select 'invoice_cancelled', v.ingestion_row_id from invoices v join orders o on v.order_id=o.order_id where o.order_status='cancelled'
    union all select 'return_credit_state', return_event_id from returns where (return_status='credited' and (credit_amount_usd_cents is null or credited_at is null or received_at is null)) or (return_status<>'credited' and (credit_amount_usd_cents is not null or credited_at is not null))
    union all select 'return_before_delivery', r.return_event_id from returns r join items i on r.order_item_id=i.order_item_id where cast(r.requested_at as timestamp)<(select min(cast(e.event_occurred_at as timestamp)) from events e where e.order_id=i.order_id and e.raw_status='delivered')
    union all select 'event_time_order', ingestion_row_id from events where cast(loaded_at as timestamp)<cast(event_occurred_at as timestamp) or cast(cast(event_occurred_at as timestamp) as date)>cast('{{ var("fixture_as_of_date") }}' as date)
    union all select 'missing_pod', ingestion_row_id from events where raw_status='delivered' and proof_of_delivery_ref is null
    union all select 'order_status', order_id from orders where order_status not in ('confirmed','processing','in_transit','fulfilled','cancelled') or currency_code<>'USD' or (order_status='cancelled' and cancelled_at is null)
    union all select 'order_lifecycle_time', order_id from orders where cast(source_updated_at as timestamp)<cast(ordered_at as timestamp) or cast(loaded_at as timestamp)<cast(source_updated_at as timestamp) or cast(cancelled_at as timestamp)>cast(source_updated_at as timestamp) or cast(cast(loaded_at as timestamp) as date)>cast('{{ var("fixture_as_of_date") }}' as date)
    union all select 'fulfilled_state_time', o.order_id from orders o where o.order_status='fulfilled' and (not exists(select 1 from events e where e.order_id=o.order_id and e.raw_status='delivered') or cast(o.source_updated_at as timestamp)<(select min(cast(e.event_occurred_at as timestamp)) from events e where e.order_id=o.order_id and e.raw_status='delivered'))
    union all select 'return_lifecycle_time', return_event_id from returns where cast(received_at as timestamp)<cast(requested_at as timestamp) or cast(credited_at as timestamp)<cast(received_at as timestamp) or cast(source_updated_at as timestamp)<cast(requested_at as timestamp) or cast(source_updated_at as timestamp)<cast(received_at as timestamp) or cast(source_updated_at as timestamp)<cast(credited_at as timestamp) or cast(loaded_at as timestamp)<cast(source_updated_at as timestamp) or cast(cast(loaded_at as timestamp) as date)>cast('{{ var("fixture_as_of_date") }}' as date) or (return_status='received' and received_at is null) or quantity<=0
    union all select 'invoice_lifecycle_time', ingestion_row_id from invoices where cast(loaded_at as timestamp)<cast(source_updated_at as timestamp) or cast(cast(source_updated_at as timestamp) as date)<cast(invoice_date as date) or cast(cast(loaded_at as timestamp) as date)>cast('{{ var("fixture_as_of_date") }}' as date)
    union all select 'future_return', return_event_id from returns where cast(cast(requested_at as timestamp) as date)>cast('{{ var("fixture_as_of_date") }}' as date) or cast(cast(credited_at as timestamp) as date)>cast('{{ var("fixture_as_of_date") }}' as date)
    union all select 'change_effective_key', account_id from changes group by account_id,effective_at having count(*)>1
)
select * from violations
