{{ config(severity='error', tags=['intentional_failure'], store_failures=true) }}
-- DQ-CAR-01: exception_hold shipped in carrier feed v2 before mapping deployment.
select event_id, order_id, shipment_id, raw_event_status, event_status, loaded_at
from {{ ref('stg_carrier_events') }} where is_unmapped = 1
