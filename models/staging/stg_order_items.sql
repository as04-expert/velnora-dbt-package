select order_item_id, order_id, line_number, sku, product_name, quantity,
       unit_price_usd_cents, unit_cost_usd_cents, discount_bps,
       line_discount_usd_cents, line_net_usd_cents, currency_code
from {{ ref('raw_order_items') }}
