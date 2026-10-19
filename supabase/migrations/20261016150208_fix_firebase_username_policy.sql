alter policy "Verified Firebase users create their own profile"
  on public.firebase_profiles
  with check (
    (select public.is_verified_conviene_firebase_user())
    and uid = auth.jwt() ->> 'sub'
    and not exists (
      select 1 from public.profiles p
      where lower(p.username) = lower(firebase_profiles.username)
    )
  );

alter policy "Verified Firebase users edit their own username"
  on public.firebase_profiles
  with check (
    (select public.is_verified_conviene_firebase_user())
    and uid = auth.jwt() ->> 'sub'
    and not exists (
      select 1 from public.profiles p
      where lower(p.username) = lower(firebase_profiles.username)
    )
  );
