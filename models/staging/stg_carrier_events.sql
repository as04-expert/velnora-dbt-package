with ranked as (
    select *, row_number() over (
        partition by event_id order by cast(loaded_at as timestamp) desc, ingestion_row_id desc
    ) as replay_rank
    from {{ ref('raw_carrier_events') }}
    where cast(cast(event_occurred_at as timestamp) as date) <= cast('{{ var("fixture_as_of_date") }}' as date)
), mapped as (
    select ingestion_row_id, event_id, shipment_id, order_id, carrier_code,
           raw_status as raw_event_status,
           case when raw_status = 'label_created' then 'label_created'
                when raw_status = 'picked_up' then 'shipped'
                when raw_status = 'in_transit' then 'in_transit'
                when raw_status = 'delivered' then 'delivered'
                {% if var('apply_incident_fixes') %}
                when raw_status = 'exception_hold' then 'on_hold'
                {% endif %}
                else 'unmapped' end as event_status,
           cast(event_occurred_at as timestamp) as event_occurred_at,
           cast(loaded_at as timestamp) as loaded_at,
           ingestion_batch_id, proof_of_delivery_ref
    from ranked where replay_rank = 1
)
select *, case when event_status = 'unmapped' then 1 else 0 end as is_unmapped
from mapped
