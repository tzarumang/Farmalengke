-- M2 / FR-5: produce listings.

create type public.listing_availability as enum ('available_now', 'expected');

create type public.listing_status as enum (
  'draft',      -- being prepared, not offered
  'active',     -- offered
  'committed',  -- reserved against an order (M2 slice 2)
  'withdrawn',  -- taken back by the farmer
  'expired'     -- passed its availability window
);

create table public.produce_listings (
  id                 uuid primary key default gen_random_uuid(),
  farmer_id          uuid not null references public.profiles (id) on delete cascade,
  farm_id            uuid not null references public.farms (id) on delete restrict,

  commodity_id       uuid not null references public.commodities (id),
  variety            text,

  -- What the farmer entered, in the unit they think in.
  quantity           numeric(12, 3) not null,
  unit_code          text not null references public.trade_units (code),

  -- The same quantity in kilograms, resolved at write time from commodity_units.
  -- Stored rather than computed on read so that a later correction to a unit
  -- conversion cannot silently restate quantities a buyer already agreed to.
  quantity_kg        numeric(12, 3) not null,

  -- FR-14 grades produce at intake; this is only what the farmer claims, and the
  -- column name says so to keep the two from being confused downstream.
  claimed_grade      text,

  availability       public.listing_availability not null,
  available_from     date,

  status             public.listing_status not null default 'draft',

  client_reference   uuid not null default gen_random_uuid(),

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint produce_listings_quantity_positive check (quantity > 0),
  constraint produce_listings_quantity_kg_positive check (quantity_kg > 0),

  -- An expected harvest needs a date; produce on hand today does not.
  constraint produce_listings_expected_needs_date
    check (availability <> 'expected' or available_from is not null)
);

create index produce_listings_farmer_idx    on public.produce_listings (farmer_id);
create index produce_listings_farm_idx      on public.produce_listings (farm_id);
create index produce_listings_commodity_idx on public.produce_listings (commodity_id);
create index produce_listings_status_idx    on public.produce_listings (status);

-- Supports the buyer browse in the next slice: active listings by commodity and date.
create index produce_listings_browse_idx
  on public.produce_listings (status, commodity_id, available_from)
  where status = 'active';

create unique index produce_listings_client_reference_unique
  on public.produce_listings (farmer_id, client_reference);

comment on column public.produce_listings.quantity_kg is
  'Quantity in kilograms at the time of writing. Frozen deliberately: correcting a '
  'unit conversion later must not restate a quantity someone already transacted on.';
comment on column public.produce_listings.claimed_grade is
  'The farmer''s own claim. The binding grade is assessed at intake — see FR-14.';

-- ---------------------------------------------------------------------------
-- Unit conversion
-- ---------------------------------------------------------------------------

-- Resolves a local trade unit to kilograms for a commodity, preferring a
-- region-specific conversion over a general one. Returns null when no conversion
-- is on record, so the caller must decide — silently guessing a weight would put
-- an invented number in front of a farmer deciding what to sell.
create or replace function public.commodity_unit_to_kg(
  p_commodity_id uuid,
  p_unit_code    text,
  p_region_code  text default null
)
returns numeric
language sql
stable
set search_path = ''
as $$
  select cu.kilograms_per_unit
  from public.commodity_units cu
  where cu.commodity_id = p_commodity_id
    and cu.unit_code = p_unit_code
    and (cu.region_code = p_region_code or cu.region_code is null)
  order by (cu.region_code is not null) desc  -- region-specific wins
  limit 1;
$$;

-- Fills quantity_kg from the conversion table, and refuses the write when no
-- conversion exists rather than storing a quantity nobody can compare.
create or replace function public.set_listing_quantity_kg()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_region text;
  v_factor numeric;
begin
  select f.region_code into v_region
  from public.farms f
  where f.id = new.farm_id;

  v_factor := public.commodity_unit_to_kg(new.commodity_id, new.unit_code, v_region);

  if v_factor is null then
    raise exception
      'no kilogram conversion on record for this commodity in unit % (region %)',
      new.unit_code, coalesce(v_region, 'any')
      using errcode = 'check_violation';
  end if;

  new.quantity_kg := round(new.quantity * v_factor, 3);
  return new;
end;
$$;

create trigger produce_listings_set_quantity_kg
  before insert or update of quantity, unit_code, commodity_id, farm_id
  on public.produce_listings
  for each row execute function public.set_listing_quantity_kg();

-- ---------------------------------------------------------------------------
-- The listing must belong to the farmer's own farm
-- ---------------------------------------------------------------------------

create or replace function public.guard_listing_farm_ownership()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.farms f
    where f.id = new.farm_id and f.farmer_id = new.farmer_id
  ) then
    raise exception 'a listing must reference a farm belonging to the same farmer'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

create trigger produce_listings_guard_farm
  before insert or update of farm_id, farmer_id
  on public.produce_listings
  for each row execute function public.guard_listing_farm_ownership();

create trigger produce_listings_touch_updated_at
  before update on public.produce_listings
  for each row execute function public.touch_updated_at();

create trigger produce_listings_audit
  after insert or update or delete on public.produce_listings
  for each row execute function public.audit_row_change();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.produce_listings enable row level security;

create policy "read own listings"
  on public.produce_listings for select to authenticated
  using ((select auth.uid()) = farmer_id);

-- Buyers and the trading desk see what is actually on offer — never drafts,
-- which are the farmer's private working state.
create policy "buyers read active listings"
  on public.produce_listings for select to authenticated
  using (
    status = 'active'
    and public.has_any_role('buyer', 'trading_desk', 'bagsakan_operator')
  );

create policy "compliance and admin read listings"
  on public.produce_listings for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

create policy "create own listings"
  on public.produce_listings for insert to authenticated
  with check ((select auth.uid()) = farmer_id);

-- A committed listing is reserved against an order; editing it out from under a
-- buyer is a settlement problem, so it is blocked at the policy level.
create policy "update own listings"
  on public.produce_listings for update to authenticated
  using ((select auth.uid()) = farmer_id and status <> 'committed')
  with check ((select auth.uid()) = farmer_id);

-- No delete policy: a listing is withdrawn, not erased, so the history of what
-- was offered survives.
