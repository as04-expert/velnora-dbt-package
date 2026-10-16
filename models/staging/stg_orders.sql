select order_id, account_id, cast(ordered_at as timestamp) as ordered_at,
       cast(cast(ordered_at as timestamp) as date) as order_date,
       cast(promised_delivery_date as date) as promised_delivery_date,
       order_status, currency_code, sales_channel, customer_po,
       cast(cancelled_at as timestamp) as cancelled_at,
       cast(source_updated_at as timestamp) as source_updated_at,
       cast(loaded_at as timestamp) as loaded_at, ingestion_batch_id
from {{ ref('raw_orders') }}
where cast(cast(ordered_at as timestamp) as date) <= cast('{{ var("fixture_as_of_date") }}' as date)
