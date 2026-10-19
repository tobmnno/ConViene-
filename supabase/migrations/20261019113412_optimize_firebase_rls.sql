create index community_prices_firebase_updated_by_idx
  on public.community_prices (firebase_updated_by)
  where firebase_updated_by is not null;

alter policy "Verified Firebase users create their own profile"
  on public.firebase_profiles
  with check (
    (select public.is_verified_conviene_firebase_user())
    and uid = (select auth.jwt() ->> 'sub')
    and not exists (
      select 1 from public.profiles p
      where lower(p.username) = lower(firebase_profiles.username)
    )
  );

alter policy "Verified Firebase users edit their own username"
  on public.firebase_profiles
  using (
    (select public.is_verified_conviene_firebase_user())
    and uid = (select auth.jwt() ->> 'sub')
  )
  with check (
    (select public.is_verified_conviene_firebase_user())
    and uid = (select auth.jwt() ->> 'sub')
    and not exists (
      select 1 from public.profiles p
      where lower(p.username) = lower(firebase_profiles.username)
    )
  );

alter policy "Verified Firebase users add community prices"
  on public.community_prices
  with check (
    (select public.is_verified_conviene_firebase_user())
    and firebase_created_by = (select auth.jwt() ->> 'sub')
    and firebase_updated_by = (select auth.jwt() ->> 'sub')
  );

alter policy "Firebase authors edit their own prices"
  on public.community_prices
  using (
    (select public.is_verified_conviene_firebase_user())
    and firebase_created_by = (select auth.jwt() ->> 'sub')
  )
  with check (
    (select public.is_verified_conviene_firebase_user())
    and firebase_created_by = (select auth.jwt() ->> 'sub')
    and firebase_updated_by = (select auth.jwt() ->> 'sub')
  );
