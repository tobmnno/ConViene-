create index community_prices_created_by_idx
  on public.community_prices (created_by);

create index community_prices_updated_by_idx
  on public.community_prices (updated_by);
