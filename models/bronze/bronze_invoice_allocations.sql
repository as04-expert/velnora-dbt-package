-- Disabled draft, owner: finance_analytics. No approved freight allocation rule.
-- TODO: obtain freight source and agree value-weighted vs weight-based allocation.
-- Acceptance: allocated freight must equal invoice freight without penny leakage.
select invoice_id, invoice_line_id, order_item_id, net_amount_usd_cents,
       cast(null as bigint) as allocated_freight_usd_cents,
       cast(null as {{ dbt.type_string() }}) as allocation_rule
from {{ ref('raw_invoice_lines') }}
