-- Guest reads expose product and public attribution only. Writes keep their
-- existing verified-user RLS policies; author identifiers stay private.
create or replace function public.search_public_community_prices(query_text text, store_ids text[])
returns table (
  id uuid, supermarket_id text, name text, brand text, presentation text,
  unit text, category text, ean text, image_url text, source_url text,
  price numeric, unit_price numeric, in_stock boolean,
  username text, updated_at timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.supermarket_id, p.name, p.brand, p.presentation,
         p.unit, p.category, p.ean, p.image_url, p.source_url,
         p.price, p.unit_price, p.in_stock,
         coalesce(u.username, f.username), p.updated_at
  from public.community_prices p
  left join public.profiles u on u.id = p.created_by
  left join public.firebase_profiles f on f.uid = p.firebase_created_by
  where char_length(trim(query_text)) between 2 and 120
    and p.supermarket_id = any(store_ids)
    and p.supermarket_id in ('coto', 'carrefour', 'lagallega')
    and (
      p.ean = query_text
      or not exists (
        select 1
        from regexp_split_to_table(
          trim(regexp_replace(lower(query_text), '[^[:alnum:]]+', ' ', 'g')),
          '\s+'
        ) as token
        where token <> ''
          and lower(p.name || ' ' || p.brand || ' ' || p.presentation)
              not like '%' || token || '%'
      )
    )
  order by p.updated_at desc
  limit 60;
$$;

create or replace function public.public_community_price_by_id(price_id uuid)
returns table (
  id uuid, supermarket_id text, name text, brand text, presentation text,
  unit text, category text, ean text, image_url text, source_url text,
  price numeric, unit_price numeric, in_stock boolean,
  username text, updated_at timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.supermarket_id, p.name, p.brand, p.presentation,
         p.unit, p.category, p.ean, p.image_url, p.source_url,
         p.price, p.unit_price, p.in_stock,
         coalesce(u.username, f.username), p.updated_at
  from public.community_prices p
  left join public.profiles u on u.id = p.created_by
  left join public.firebase_profiles f on f.uid = p.firebase_created_by
  where p.id = price_id;
$$;

revoke all on function public.search_public_community_prices(text, text[]) from public;
revoke all on function public.public_community_price_by_id(uuid) from public;
grant execute on function public.search_public_community_prices(text, text[]) to anon, authenticated;
grant execute on function public.public_community_price_by_id(uuid) to anon, authenticated;
