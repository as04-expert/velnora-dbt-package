with changes as (
    select change_id, account_id, customer_tier, payment_terms_days,
           credit_limit_usd_cents, account_status, change_reason,
           cast(effective_at as timestamp) as valid_from,
           cast(source_updated_at as timestamp) as source_updated_at
    from {{ ref('raw_account_changes') }}
    where cast(cast(effective_at as timestamp) as date) <= cast('{{ var("fixture_as_of_date") }}' as date)
)
select *, lead(valid_from) over (partition by account_id order by valid_from) as valid_to,
       case when lead(valid_from) over (partition by account_id order by valid_from) is null
            then 1 else 0 end as is_current
from changes
