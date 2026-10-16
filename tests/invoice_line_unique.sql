{{ config(severity='error', tags=['data_quality'], store_failures=true) }}
select invoice_line_id, min(invoice_id) as invoice_id, min(order_id) as order_id,
       count(*) as observed_rows, sum(net_amount_usd_cents) as observed_amount_usd_cents
from {{ ref('fct_invoice_lines') }}
group by invoice_line_id having count(*) > 1
