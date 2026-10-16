-- Disabled draft, owner: support_data. Payload 1.1 removed serial arrays.
-- TODO: agree v1.1 serial fallback and disposition lookup with Support Ops.
-- Acceptance: preserve all 8 RMA IDs; explain missing serials; reconcile credit lifecycle.
select return_event_id, rma_id, order_item_id, return_status, payload_schema_version,
       raw_payload, cast(requested_at as timestamp) as requested_at,
       cast(null as {{ dbt.type_string() }}) as serial_number,
       cast(null as {{ dbt.type_string() }}) as disposition_category
from {{ ref('raw_return_events') }}
