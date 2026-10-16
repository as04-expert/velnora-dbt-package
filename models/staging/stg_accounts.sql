select account_id, account_name, industry, region, country_code, customer_tier,
       payment_terms_days, credit_limit_usd_cents, account_status,
       cast(created_at as timestamp) as created_at,
       cast(updated_at as timestamp) as updated_at, source_system
from {{ ref('raw_accounts') }}
