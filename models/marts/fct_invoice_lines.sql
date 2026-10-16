with landing as (
    select *, row_number() over (
        partition by invoice_line_id, invoice_id, order_id, order_item_id,
                     invoice_date, due_date, quantity, net_amount_usd_cents,
                     currency_code, source_updated_at
        order by cast(loaded_at as timestamp) desc, ingestion_row_id desc
    ) as replay_rank
    from {{ ref('raw_invoice_lines') }}
)
select ingestion_row_id, invoice_line_id, invoice_id, order_id, order_item_id,
       cast(invoice_date as date) as invoice_date, cast(due_date as date) as due_date,
       quantity, net_amount_usd_cents, currency_code,
       cast(source_updated_at as timestamp) as source_updated_at,
       cast(loaded_at as timestamp) as loaded_at, ingestion_batch_id
from landing
{% if var('apply_incident_fixes') %}
where replay_rank = 1
{% endif %}
