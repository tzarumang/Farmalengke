-- M2 / FR-3: farm records.
--
-- A farmer may register several farms. Location is barangay-level by default;
-- a GPS point is optional, requires explicit recorded consent, and is retained
-- for 24 months (PRD section 9). A farm's GPS point is effectively the farmer's
-- workplace and often their home, which is why it is opt-in rather than ambient.

create type public.area_unit as enum ('hectare', 'square_metre');

create table public.farms (
  id                 uuid primary key default gen_random_uuid(),
  farmer_id          uuid not null references public.profiles (id) on delete cascade,

  name               text not null,
  region_code        text not null references public.regions (code),

  -- Coarse location, always present.
  barangay           text not null,
  city_municipality  text not null,
  province           text not null,

  area_value         numeric(10, 4),
  area_unit          public.area_unit,

  -- Precise location, only with consent. The consent timestamp is stored beside
  -- the coordinates so "did they agree to this?" is answerable from one row.
  gps_latitude       numeric(9, 6),
  gps_longitude      numeric(9, 6),
  gps_consent_at     timestamptz,

  -- Offline capture (FR-3, FR-5): the device generates this before it can reach
  -- the server, so a retried sync updates one row instead of creating duplicates.
  client_reference   uuid not null default gen_random_uuid(),

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint farms_name_not_blank check (length(btrim(name)) > 0),
  constraint farms_barangay_not_blank check (length(btrim(barangay)) > 0),

  -- Area is a value and a unit together, or neither. A bare number is not a size.
  constraint farms_area_complete
    check ((area_value is null) = (area_unit is null)),
  constraint farms_area_positive
    check (area_value is null or area_value > 0),

  -- Coordinates arrive as a pair, and never without recorded consent.
  constraint farms_gps_pair
    check ((gps_latitude is null) = (gps_longitude is null)),
  constraint farms_gps_requires_consent
    check (gps_latitude is null or gps_consent_at is not null),
  constraint farms_gps_in_range
    check (
      gps_latitude is null
      or (gps_latitude between -90 and 90 and gps_longitude between -180 and 180)
    )
);

create index farms_farmer_id_idx on public.farms (farmer_id);
create index farms_region_code_idx on public.farms (region_code);

-- Idempotent offline sync: one client reference per farmer.
create unique index farms_client_reference_unique
  on public.farms (farmer_id, client_reference);

comment on column public.farms.gps_consent_at is
  'When the farmer agreed to store a precise location. Coordinates without this '
  'are rejected by farms_gps_requires_consent.';
comment on column public.farms.client_reference is
  'Device-generated id so an offline record that syncs twice updates one row.';

-- ---------------------------------------------------------------------------
-- What each farm grows (FR-3: crops with expected harvest months)
-- ---------------------------------------------------------------------------

create table public.farm_crops (
  id                     uuid primary key default gen_random_uuid(),
  farm_id                uuid not null references public.farms (id) on delete cascade,
  commodity_id           uuid not null references public.commodities (id),

  -- 1-12. An array rather than a season enum: Philippine cropping is not neatly
  -- two seasons everywhere, and a farmer knows their own months.
  expected_harvest_months smallint[] not null default '{}',

  created_at             timestamptz not null default now(),

  constraint farm_crops_months_valid
    check (
      expected_harvest_months <@ array[1,2,3,4,5,6,7,8,9,10,11,12]::smallint[]
    )
);

create unique index farm_crops_unique on public.farm_crops (farm_id, commodity_id);
create index farm_crops_farm_id_idx on public.farm_crops (farm_id);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

create trigger farms_touch_updated_at
  before update on public.farms
  for each row execute function public.touch_updated_at();

create trigger farms_audit
  after insert or update or delete on public.farms
  for each row execute function public.audit_row_change();

create trigger farm_crops_audit
  after insert or update or delete on public.farm_crops
  for each row execute function public.audit_row_change();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.farms enable row level security;
alter table public.farm_crops enable row level security;

create policy "read own farms"
  on public.farms for select to authenticated
  using ((select auth.uid()) = farmer_id);

-- Compliance and admin only. The trading desk buys produce; it has no reason to
-- hold a map of where farmers live.
create policy "compliance and admin read farms"
  on public.farms for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

create policy "create own farms"
  on public.farms for insert to authenticated
  with check ((select auth.uid()) = farmer_id);

create policy "update own farms"
  on public.farms for update to authenticated
  using ((select auth.uid()) = farmer_id)
  with check ((select auth.uid()) = farmer_id);

create policy "delete own farms"
  on public.farms for delete to authenticated
  using ((select auth.uid()) = farmer_id);

create policy "read own farm crops"
  on public.farm_crops for select to authenticated
  using (exists (
    select 1 from public.farms f
    where f.id = farm_crops.farm_id and f.farmer_id = (select auth.uid())
  ));

create policy "compliance and admin read farm crops"
  on public.farm_crops for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

create policy "write own farm crops"
  on public.farm_crops for all to authenticated
  using (exists (
    select 1 from public.farms f
    where f.id = farm_crops.farm_id and f.farmer_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.farms f
    where f.id = farm_crops.farm_id and f.farmer_id = (select auth.uid())
  ));
