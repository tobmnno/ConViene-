create table public.firebase_profiles (
  uid text primary key check (uid ~ '^[A-Za-z0-9_-]{1,128}$'),
  username text not null check (username ~ '^[A-Za-z0-9_]{3,30}$'),
  created_at timestamptz not null default now()
);

create unique index firebase_profiles_username_unique
  on public.firebase_profiles (lower(username));

create function public.is_verified_conviene_firebase_user()
returns boolean
language sql
stable
set search_path = ''
as $$
  select auth.jwt() ->> 'iss' = 'https://securetoken.google.com/conviene-87c27'
    and auth.jwt() ->> 'aud' = 'conviene-87c27'
    and auth.jwt() ->> 'email_verified' = 'true'
    and coalesce(auth.jwt() ->> 'sub', '') ~ '^[A-Za-z0-9_-]{1,128}$';
$$;

alter table public.community_prices
  alter column created_by drop not null,
  alter column updated_by drop not null,
  alter column created_by drop default,
  alter column updated_by drop default,
  add column firebase_created_by text references public.firebase_profiles(uid),
  add column firebase_updated_by text references public.firebase_profiles(uid),
  add constraint community_prices_one_creator check (
    (created_by is not null) <> (firebase_created_by is not null)
  ),
  add constraint community_prices_one_editor check (
    (updated_by is not null) <> (firebase_updated_by is not null)
  );

create index community_prices_firebase_created_by_idx
  on public.community_prices (firebase_created_by)
  where firebase_created_by is not null;

create function public.assign_community_price_author()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select public.is_verified_conviene_firebase_user()) then
    new.created_by := null;
    new.updated_by := null;
    new.firebase_created_by := auth.jwt() ->> 'sub';
    new.firebase_updated_by := new.firebase_created_by;
  else
    new.created_by := auth.uid();
    new.updated_by := new.created_by;
    new.firebase_created_by := null;
    new.firebase_updated_by := null;
  end if;
  return new;
end;
$$;

create trigger assign_community_price_author_before_insert
before insert on public.community_prices
for each row execute function public.assign_community_price_author();

create or replace function public.stamp_community_price()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.created_by := old.created_by;
  new.firebase_created_by := old.firebase_created_by;
  new.created_at := old.created_at;
  if (select public.is_verified_conviene_firebase_user()) then
    new.updated_by := null;
    new.firebase_updated_by := auth.jwt() ->> 'sub';
  else
    new.updated_by := auth.uid();
    new.firebase_updated_by := null;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

alter table public.firebase_profiles enable row level security;
revoke all on public.firebase_profiles from anon, authenticated;
grant select on public.firebase_profiles to anon, authenticated;
grant insert (uid, username) on public.firebase_profiles to anon;
grant update (username) on public.firebase_profiles to anon;

create policy "Verified Firebase users read public Firebase usernames"
  on public.firebase_profiles for select to anon
  using ((select public.is_verified_conviene_firebase_user()));
create policy "Supabase users read public Firebase usernames"
  on public.firebase_profiles for select to authenticated using (true);
create policy "Verified Firebase users create their own profile"
  on public.firebase_profiles for insert to anon
  with check (
    (select public.is_verified_conviene_firebase_user())
    and uid = auth.jwt() ->> 'sub'
    and not exists (
      select 1 from public.profiles p
      where lower(p.username) = lower(username)
    )
  );
create policy "Verified Firebase users edit their own username"
  on public.firebase_profiles for update to anon
  using (
    (select public.is_verified_conviene_firebase_user())
    and uid = auth.jwt() ->> 'sub'
  )
  with check (
    (select public.is_verified_conviene_firebase_user())
    and uid = auth.jwt() ->> 'sub'
    and not exists (
      select 1 from public.profiles p
      where lower(p.username) = lower(username)
    )
  );

grant select on public.profiles to anon;
create policy "Verified Firebase users read public Supabase usernames"
  on public.profiles for select to anon
  using ((select public.is_verified_conviene_firebase_user()));

grant select on public.community_prices to anon;
grant insert (supermarket_id, name, brand, presentation, unit, category, ean,
              image_url, source_url, price, unit_price, in_stock)
  on public.community_prices to anon;
grant update (name, brand, presentation, unit, category, ean, image_url,
              source_url, price, unit_price, in_stock)
  on public.community_prices to anon;

create policy "Verified Firebase users read community prices"
  on public.community_prices for select to anon
  using ((select public.is_verified_conviene_firebase_user()));
create policy "Verified Firebase users add community prices"
  on public.community_prices for insert to anon
  with check (
    (select public.is_verified_conviene_firebase_user())
    and firebase_created_by = auth.jwt() ->> 'sub'
    and firebase_updated_by = auth.jwt() ->> 'sub'
  );
create policy "Firebase authors edit their own prices"
  on public.community_prices for update to anon
  using (
    (select public.is_verified_conviene_firebase_user())
    and firebase_created_by = auth.jwt() ->> 'sub'
  )
  with check (
    (select public.is_verified_conviene_firebase_user())
    and firebase_created_by = auth.jwt() ->> 'sub'
    and firebase_updated_by = auth.jwt() ->> 'sub'
  );

drop function public.search_community_prices(text, text[]);
create function public.search_community_prices(query_text text, store_ids text[])
returns table (
  id uuid, supermarket_id text, name text, brand text, presentation text,
  unit text, category text, ean text, image_url text, source_url text,
  price numeric, unit_price numeric, in_stock boolean,
  created_by text, username text, updated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select p.id, p.supermarket_id, p.name, p.brand, p.presentation,
         p.unit, p.category, p.ean, p.image_url, p.source_url,
         p.price, p.unit_price, p.in_stock,
         coalesce(p.created_by::text, p.firebase_created_by),
         coalesce(u.username, f.username), p.updated_at
  from public.community_prices p
  left join public.profiles u on u.id = p.created_by
  left join public.firebase_profiles f on f.uid = p.firebase_created_by
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
grant execute on function public.search_community_prices(text, text[]) to anon, authenticated;
revoke all on function public.is_verified_conviene_firebase_user() from public;
grant execute on function public.is_verified_conviene_firebase_user() to anon, authenticated;
revoke all on function public.assign_community_price_author() from public, anon, authenticated;
