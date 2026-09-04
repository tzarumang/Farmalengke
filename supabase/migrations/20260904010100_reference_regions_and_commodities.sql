-- M2: reference data for regions, commodities, and trade units.
--
-- These are seeded reference tables rather than enums so that adding a commodity
-- or a region is a data change, not a migration. PRD Q10 (which region, which
-- commodities) is still open in principle; the rows below are the client's
-- current answer and can be edited without touching schema.

-- ---------------------------------------------------------------------------
-- Regions
-- ---------------------------------------------------------------------------

create table public.regions (
  code        text primary key,
  name        text not null,
  country     text not null default 'PH',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),

  constraint regions_code_format check (code ~ '^[A-Z0-9_-]{2,16}$')
);

comment on table public.regions is
  'Operating regions. Country is explicit so a later market is a row, not a rewrite.';

insert into public.regions (code, name) values
  ('PH-CAR', 'Cordillera Administrative Region'),
  ('PH-R03', 'Central Luzon');

-- ---------------------------------------------------------------------------
-- Commodities
-- ---------------------------------------------------------------------------

create table public.commodities (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  name_en       text not null,
  name_fil      text not null,

  -- Metric is the canonical unit for every comparison and settlement figure.
  -- Local trade units are a display and entry convenience layered on top.
  base_unit     text not null default 'kg',

  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),

  constraint commodities_code_format check (code ~ '^[a-z0-9_]{2,32}$'),
  constraint commodities_base_unit_metric check (base_unit in ('kg'))
);

create index commodities_is_active_idx on public.commodities (is_active);

comment on column public.commodities.base_unit is
  'Always kilograms. Local units convert to this — see commodity_units.';

insert into public.commodities (code, name_en, name_fil) values
  -- Cordillera highland vegetables
  ('cabbage',      'Cabbage',      'Repolyo'),
  ('potato',       'Potato',       'Patatas'),
  ('carrot',       'Carrot',       'Karot'),
  ('chayote',      'Chayote',      'Sayote'),
  -- Grown in both regions
  ('tomato',       'Tomato',       'Kamatis'),
  -- Central Luzon lowland vegetables
  ('eggplant',     'Eggplant',     'Talong'),
  ('bitter_gourd', 'Bitter gourd', 'Ampalaya'),
  ('string_beans', 'String beans', 'Sitaw'),
  ('squash',       'Squash',       'Kalabasa');

-- Which commodities each region actually trades. A listing is not restricted to
-- these, but they drive what is offered first in the interface.
create table public.region_commodities (
  region_code  text not null references public.regions (code) on delete cascade,
  commodity_id uuid not null references public.commodities (id) on delete cascade,
  primary key (region_code, commodity_id)
);

insert into public.region_commodities (region_code, commodity_id)
select 'PH-CAR', id from public.commodities
 where code in ('cabbage', 'potato', 'carrot', 'chayote', 'tomato');

insert into public.region_commodities (region_code, commodity_id)
select 'PH-R03', id from public.commodities
 where code in ('eggplant', 'bitter_gourd', 'string_beans', 'squash', 'tomato');

-- ---------------------------------------------------------------------------
-- Trade units
-- ---------------------------------------------------------------------------
--
-- PRD section 8: "Metric primary, with local trade units (kaban, sako) displayed
-- alongside and configurable per commodity per region." A sako of one commodity
-- does not weigh the same as a sako of another, and conventions differ by region,
-- so the conversion is keyed on all three.

create table public.trade_units (
  code       text primary key,
  name_en    text not null,
  name_fil   text not null,
  is_metric  boolean not null default false,

  constraint trade_units_code_format check (code ~ '^[a-z_]{2,16}$')
);

insert into public.trade_units (code, name_en, name_fil, is_metric) values
  ('kg',    'Kilogram', 'Kilo',   true),
  ('sako',  'Sack',     'Sako',   false),
  ('kaban', 'Kaban',    'Kaban',  false),
  ('bag',   'Bag',      'Bag',    false),
  ('crate', 'Crate',    'Kaha',   false);

create table public.commodity_units (
  id                  uuid primary key default gen_random_uuid(),
  commodity_id        uuid not null references public.commodities (id) on delete cascade,
  unit_code           text not null references public.trade_units (code),

  -- The whole point of this table: what this unit weighs, for this commodity,
  -- in this region. Null region means the conversion applies everywhere.
  region_code         text references public.regions (code) on delete cascade,
  kilograms_per_unit  numeric(10, 3) not null,

  -- Conventions vary between traders, so a conversion must be attributable and
  -- correctable rather than presented as a fact of nature.
  source_note         text,
  created_at          timestamptz not null default now(),

  constraint commodity_units_positive check (kilograms_per_unit > 0)
);

create unique index commodity_units_unique
  on public.commodity_units (commodity_id, unit_code, coalesce(region_code, ''));

create index commodity_units_commodity_idx on public.commodity_units (commodity_id);

comment on table public.commodity_units is
  'Local trade unit conversions. Deliberately per commodity and per region: a sako '
  'of cabbage and a sako of potato are not the same weight.';

-- Kilogram is the identity conversion for every commodity.
insert into public.commodity_units (commodity_id, unit_code, region_code, kilograms_per_unit, source_note)
select id, 'kg', null, 1.000, 'Metric identity.'
from public.commodities;

-- No sako or kaban conversions are seeded. Inventing weights would put an
-- unsourced number in front of a farmer deciding what to sell, which PRD section 9
-- forbids. Operations captures these per region before launch — see PRD Q11.

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
--
-- Reference data is readable by every signed-in user and writable only by an
-- administrator. It is not secret, but it is not user-editable either: a farmer
-- who could rewrite a unit conversion could rewrite what they get paid.

alter table public.regions            enable row level security;
alter table public.commodities        enable row level security;
alter table public.region_commodities enable row level security;
alter table public.trade_units        enable row level security;
alter table public.commodity_units    enable row level security;

create policy "signed-in users read regions"
  on public.regions for select to authenticated using (true);
create policy "admin writes regions"
  on public.regions for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));

create policy "signed-in users read commodities"
  on public.commodities for select to authenticated using (true);
create policy "admin writes commodities"
  on public.commodities for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));

create policy "signed-in users read region commodities"
  on public.region_commodities for select to authenticated using (true);
create policy "admin writes region commodities"
  on public.region_commodities for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));

create policy "signed-in users read trade units"
  on public.trade_units for select to authenticated using (true);
create policy "admin writes trade units"
  on public.trade_units for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));

create policy "signed-in users read commodity units"
  on public.commodity_units for select to authenticated using (true);
create policy "admin writes commodity units"
  on public.commodity_units for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));

-- A conversion change alters what a farmer is paid, so it is audited.
create trigger commodity_units_audit
  after insert or update or delete on public.commodity_units
  for each row execute function public.audit_row_change();
