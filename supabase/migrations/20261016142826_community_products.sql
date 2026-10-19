create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null check (username ~ '^[A-Za-z0-9_]{3,30}$'),
  created_at timestamptz not null default now()
);

create unique index profiles_username_unique on public.profiles (lower(username));

create function public.create_profile_for_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, new.raw_user_meta_data ->> 'username');
  return new;
end;
$$;

create trigger create_profile_after_signup
after insert on auth.users
for each row execute function public.create_profile_for_user();

create table public.community_prices (
  id uuid primary key default gen_random_uuid(),
  supermarket_id text not null check (supermarket_id in ('coto', 'carrefour', 'lagallega')),
  name text not null check (char_length(trim(name)) between 3 and 180),
  brand text not null default '' check (char_length(brand) <= 80),
  presentation text not null check (char_length(trim(presentation)) between 1 and 80),
  unit text not null check (char_length(trim(unit)) between 1 and 20),
  category text not null default '' check (char_length(category) <= 80),
  ean text not null default '' check (ean = '' or ean ~ '^[0-9]{8,14}$'),
  image_url text not null default '' check (image_url = '' or (char_length(image_url) <= 1000 and image_url ~ '^https://')),
  source_url text not null default '' check (source_url = '' or (char_length(source_url) <= 1000 and source_url ~ '^https://')),
  price numeric(12, 2) not null check (price > 0 and price <= 9999999999),
  unit_price numeric(12, 2) not null check (unit_price > 0 and unit_price <= 9999999999),
  in_stock boolean not null default true,
  created_by uuid not null default auth.uid() references public.profiles(id),
  updated_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index community_prices_store_updated_idx
  on public.community_prices (supermarket_id, updated_at desc);
create index community_prices_ean_idx
  on public.community_prices (ean) where ean <> '';

create function public.stamp_community_price()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.created_by := old.created_by;
  new.created_at := old.created_at;
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end;
$$;

create trigger stamp_community_price_before_update
before update on public.community_prices
for each row execute function public.stamp_community_price();

alter table public.profiles enable row level security;
alter table public.community_prices enable row level security;

revoke all on public.profiles from anon, authenticated;
revoke all on public.community_prices from anon, authenticated;
grant select on public.profiles to authenticated;
grant select on public.community_prices to authenticated;
grant insert (supermarket_id, name, brand, presentation, unit, category, ean,
              image_url, source_url, price, unit_price, in_stock)
  on public.community_prices to authenticated;
grant update (name, brand, presentation, unit, category, ean, image_url,
              source_url, price, unit_price, in_stock)
  on public.community_prices to authenticated;

create policy "Signed-in users can read usernames"
  on public.profiles for select to authenticated using (true);
create policy "Signed-in users can read community prices"
  on public.community_prices for select to authenticated using (true);
create policy "Signed-in users can add community prices"
  on public.community_prices for insert to authenticated
  with check (created_by = (select auth.uid()) and updated_by = (select auth.uid()));
create policy "Authors can edit their own prices"
  on public.community_prices for update to authenticated
  using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid()) and updated_by = (select auth.uid()));

create function public.search_community_prices(query_text text, store_ids text[])
returns table (
  id uuid, supermarket_id text, name text, brand text, presentation text,
  unit text, category text, ean text, image_url text, source_url text,
  price numeric, unit_price numeric, in_stock boolean,
  created_by uuid, username text, updated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select p.id, p.supermarket_id, p.name, p.brand, p.presentation,
         p.unit, p.category, p.ean, p.image_url, p.source_url,
         p.price, p.unit_price, p.in_stock,
         p.created_by, u.username, p.updated_at
  from public.community_prices p
  join public.profiles u on u.id = p.created_by
  where char_length(trim(query_text)) between 2 and 120
    and p.supermarket_id = any(store_ids)
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

revoke all on function public.search_community_prices(text, text[]) from public, anon;
grant execute on function public.search_community_prices(text, text[]) to authenticated;
revoke all on function public.create_profile_for_user() from public, anon, authenticated;
revoke all on function public.stamp_community_price() from public, anon, authenticated;
