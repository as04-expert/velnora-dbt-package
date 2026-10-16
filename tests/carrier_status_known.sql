{{ config(severity='error', tags=['data_quality'], store_failures=true) }}
select event_id, order_id, shipment_id, raw_event_status, event_status, loaded_at
from {{ ref('stg_carrier_events') }} where is_unmapped = 1
