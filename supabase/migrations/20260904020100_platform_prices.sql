-- M2 slice 2 / FR-9: the platform's published buying price.
--
-- This is the price the platform itself pays as principal buyer, and the benchmark
-- a farmer judges their own asking price against (FR-6). It is not the price a
-- marketplace order transacts at — that is the farmer's asking price.

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------
--
-- FR-8 requires the farmer's confirmation window to be "configurable". A settings
-- row makes that true without inventing an admin screen this slice does not need.

create table public.platform_settings (
  key         text primary key,
  value       text not null,
  description text not null,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references auth.users (id)
);

insert into public.platform_settings (key, value, description) values
  ('order_confirmation_window_hours', '24',
   'How long a farmer has to confirm a reservation before it lapses (FR-8).');

create trigger platform_settings_touch_updated_at
  before update on public.platform_settings
  for each row execute function public.touch_updated_at();

create trigger platform_settings_audit
  after insert or update or delete on public.platform_settings
  for each row execute function public.audit_row_change();

create or replace function public.setting_int(p_key text, p_default int)
returns int
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select nullif(s.value, '')::int from public.platform_settings s where s.key = p_key),
    p_default
  );
$$;

-- ---------------------------------------------------------------------------
-- Published prices
-- ---------------------------------------------------------------------------

create table public.platform_prices (
  id             uuid primary key default gen_random_uuid(),

  commodity_id   uuid not null references public.commodities (id) on delete cascade,

  -- PRD Q11 (which grading standard applies) is still open, so grade is nullable
  -- and a null price applies to any grade. Once a standard exists, grade-specific
  -- rows layer on top without a migration.
  grade          text,

  -- FR-9 keys prices to a bagsakan site. Sites arrive with M3, so the region is
  -- the stand-in: a site belongs to exactly one region, and a region-level price
  -- is the right default until sites can differ.
  region_code    text not null references public.regions (code) on delete cascade,

  price_per_kg   numeric(12, 4) not null,
  currency       text not null default 'PHP',

  -- May be in the future: FR-9 requires prices to be schedulable ahead.
  effective_from timestamptz not null default now(),

  created_by     uuid references auth.users (id),
  created_at     timestamptz not null default now(),

  constraint platform_prices_positive check (price_per_kg > 0),
  constraint platform_prices_currency check (currency ~ '^[A-Z]{3}$')
);

-- The lookup this table exists for: newest effective price at or before a moment.
create index platform_prices_lookup_idx
  on public.platform_prices (commodity_id, region_code, effective_from desc);

create index platform_prices_effective_from_idx
  on public.platform_prices (effective_from desc);

comment on table public.platform_prices is
  'Append-only price history. A price is superseded by a newer row, never edited, '
  'so what was published at any past moment stays answerable.';
comment on column public.platform_prices.region_code is
  'Stands in for the bagsakan site until sites exist at M3.';

-- ---------------------------------------------------------------------------
-- Prices are history, not state
-- ---------------------------------------------------------------------------
--
-- FR-9 requires that a price change never retroactively alters a committed order.
-- Orders snapshot their price, and this table refuses edits, so a past price
-- cannot be rewritten from either direction.

create or replace function public.reject_price_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception
    'platform_prices is append-only: publish a new price instead of editing (%)', tg_op
    using errcode = 'insufficient_privilege';
end;
$$;

create trigger platform_prices_no_update
  before update on public.platform_prices
  for each row execute function public.reject_price_mutation();

create trigger platform_prices_no_delete
  before delete on public.platform_prices
  for each row execute function public.reject_price_mutation();

create trigger platform_prices_audit
  after insert on public.platform_prices
  for each row execute function public.audit_row_change();

-- ---------------------------------------------------------------------------
-- Reading prices
-- ---------------------------------------------------------------------------

-- The price in force for a commodity and region at a moment. Null when nothing
-- has been published: FR-6 forbids showing a price without a source, so callers
-- must render "no price yet" rather than a zero.
create or replace function public.current_platform_price(
  p_commodity_id uuid,
  p_region_code  text,
  p_at           timestamptz default now()
)
returns numeric
language sql
stable
set search_path = ''
as $$
  select pp.price_per_kg
  from public.platform_prices pp
  where pp.commodity_id = p_commodity_id
    and pp.region_code = p_region_code
    and pp.effective_from <= p_at
  order by pp.effective_from desc, pp.created_at desc
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.platform_settings enable row level security;
alter table public.platform_prices enable row level security;

-- Settings are operational configuration, not user data.
create policy "signed-in users read settings"
  on public.platform_settings for select to authenticated using (true);
create policy "admin writes settings"
  on public.platform_settings for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));

-- Published prices are public to every signed-in user by design: a price a farmer
-- cannot see is not price transparency (G1).
create policy "signed-in users read published prices"
  on public.platform_prices for select to authenticated
  using (effective_from <= now());

-- Scheduled future prices are the trading desk's working state until they take
-- effect. Showing a farmer tomorrow's bid today would move today's market.
create policy "trading desk and admin read all prices"
  on public.platform_prices for select to authenticated
  using (public.has_any_role('trading_desk', 'admin'));

-- Only the trading desk sets prices, and only in its own name — FR-9 requires the
-- change to be attributable to a person.
create policy "trading desk publishes prices"
  on public.platform_prices for insert to authenticated
  with check (
    public.has_any_role('trading_desk', 'admin')
    and created_by = (select auth.uid())
  );

-- No update or delete policy: the table is history.
revoke update, delete on public.platform_prices from anon, authenticated;
