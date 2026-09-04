-- M2 slice 2 / FR-8: buyer orders against listings.
--
-- An order aggregates one or more listings. Placing it reserves them, and each
-- farmer confirms their own part: an order spanning three farmers is three
-- separate decisions, not one, so confirmation lives on the line rather than the
-- order.
--
-- Reservation is whole-listing. FR-8 describes aggregating listings to reach a
-- volume rather than splitting one, and partial reservation needs remaining-
-- quantity bookkeeping this slice does not have. A farmer who wants to sell in
-- parts lists in parts. This is a real limitation, recorded rather than hidden.

create type public.order_status as enum (
  'pending',    -- placed, awaiting farmer confirmation on one or more lines
  'confirmed',  -- every line confirmed
  'partial',    -- some lines confirmed, others declined or lapsed
  'declined',   -- no line confirmed
  'cancelled'   -- withdrawn by the buyer before confirmation
);

create type public.order_line_status as enum (
  'pending',
  'confirmed',
  'declined',
  'lapsed',     -- the farmer did not answer within the window
  'cancelled'
);

create table public.orders (
  id                 uuid primary key default gen_random_uuid(),
  buyer_id           uuid not null references public.profiles (id) on delete restrict,

  status             public.order_status not null default 'pending',

  delivery_date      date not null,
  delivery_barangay  text not null,
  delivery_city      text not null,
  delivery_province  text not null,

  -- Snapshot at placement. FR-9 requires that a later price change never
  -- retroactively alters a committed order, so nothing here is recomputed.
  total_price        numeric(14, 2) not null default 0,
  currency           text not null default 'PHP',

  -- Configurable per FR-8, defaulted from platform_settings at placement.
  confirmation_deadline timestamptz not null,

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint orders_currency check (currency ~ '^[A-Z]{3}$'),
  constraint orders_total_non_negative check (total_price >= 0)
);

create index orders_buyer_idx on public.orders (buyer_id);
create index orders_status_idx on public.orders (status);
create index orders_deadline_idx on public.orders (confirmation_deadline)
  where status = 'pending';

create table public.order_lines (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references public.orders (id) on delete cascade,
  listing_id     uuid not null references public.produce_listings (id) on delete restrict,

  -- Both parties are denormalised onto the line, and not only to save a join:
  -- a policy on order_lines that queried orders, while a policy on orders queried
  -- order_lines, is mutually recursive and Postgres rejects it outright. Carrying
  -- both ids here means line policies never consult orders, which breaks the cycle.
  farmer_id      uuid not null references public.profiles (id) on delete restrict,
  buyer_id       uuid not null references public.profiles (id) on delete restrict,

  quantity_kg    numeric(12, 3) not null,
  price_per_kg   numeric(12, 4) not null,
  line_total     numeric(14, 2) not null,

  status         public.order_line_status not null default 'pending',
  responded_at   timestamptz,

  created_at     timestamptz not null default now(),

  constraint order_lines_quantity_positive check (quantity_kg > 0),
  constraint order_lines_price_positive check (price_per_kg > 0),
  constraint order_lines_total_positive check (line_total > 0),
  -- A decision must be attributable to a moment.
  constraint order_lines_response_recorded
    check (status in ('pending', 'cancelled') or responded_at is not null)
);

create index order_lines_order_idx on public.order_lines (order_id);
create index order_lines_farmer_idx on public.order_lines (farmer_id);
create index order_lines_buyer_idx on public.order_lines (buyer_id);

-- This is what prevents double-selling: a listing can appear in at most one order
-- line that is still live. A declined or lapsed line releases it.
create unique index order_lines_one_live_reservation_per_listing
  on public.order_lines (listing_id)
  where status in ('pending', 'confirmed');

comment on index public.order_lines_one_live_reservation_per_listing is
  'FR-8 double-sell prevention: at most one live reservation per listing.';

-- ---------------------------------------------------------------------------
-- Placing an order
-- ---------------------------------------------------------------------------

-- Reserving a listing is several writes that must not half-happen: check it is
-- offered, take a price snapshot, mark it committed, record the line. A function
-- keeps them in one statement and one place, rather than trusting each caller.
create or replace function public.place_order(
  p_listing_ids       uuid[],
  p_delivery_date     date,
  p_delivery_barangay text,
  p_delivery_city     text,
  p_delivery_province text
)
returns uuid
language plpgsql
-- SECURITY DEFINER on purpose. Reserving a listing is several writes that must
-- hold together, so orders and order_lines carry no insert policy at all and this
-- function is the only way in. That means it owns the authorisation it bypasses:
-- it checks the caller is signed in, holds a buying role, and that every listing
-- is genuinely on offer, before it writes anything.
security definer
set search_path = ''
as $$
declare
  v_buyer   uuid := auth.uid();
  v_order   uuid;
  v_window  int;
  v_listing record;
  v_total   numeric(14, 2) := 0;
  v_count   int := 0;
begin
  if v_buyer is null then
    raise exception 'not signed in' using errcode = 'insufficient_privilege';
  end if;

  if not public.has_any_role('buyer', 'trading_desk', 'admin') then
    raise exception 'only a buyer may place an order'
      using errcode = 'insufficient_privilege';
  end if;

  if p_listing_ids is null or array_length(p_listing_ids, 1) is null then
    raise exception 'an order needs at least one listing'
      using errcode = 'check_violation';
  end if;

  if p_delivery_date < current_date then
    raise exception 'the delivery date cannot be in the past'
      using errcode = 'check_violation';
  end if;

  v_window := public.setting_int('order_confirmation_window_hours', 24);

  insert into public.orders (
    buyer_id, delivery_date, delivery_barangay, delivery_city, delivery_province,
    confirmation_deadline
  )
  values (
    v_buyer, p_delivery_date, p_delivery_barangay, p_delivery_city, p_delivery_province,
    now() + make_interval(hours => v_window)
  )
  returning id into v_order;

  for v_listing in
    select l.id, l.farmer_id, l.quantity_kg, l.asking_price_per_kg, l.status
    from public.produce_listings l
    where l.id = any (p_listing_ids)
    -- Serialise concurrent buyers: two orders racing for the same listing queue
    -- here, and the second sees it already committed.
    for update
  loop
    if v_listing.status <> 'active' then
      raise exception 'listing % is no longer available', v_listing.id
        using errcode = 'check_violation';
    end if;

    if v_listing.asking_price_per_kg is null then
      raise exception 'listing % has no asking price', v_listing.id
        using errcode = 'check_violation';
    end if;

    insert into public.order_lines (
      order_id, listing_id, farmer_id, buyer_id, quantity_kg, price_per_kg, line_total
    )
    values (
      v_order, v_listing.id, v_listing.farmer_id, v_buyer,
      v_listing.quantity_kg, v_listing.asking_price_per_kg,
      round(v_listing.quantity_kg * v_listing.asking_price_per_kg, 2)
    );

    update public.produce_listings
       set status = 'committed'
     where id = v_listing.id;

    v_total := v_total + round(v_listing.quantity_kg * v_listing.asking_price_per_kg, 2);
    v_count := v_count + 1;
  end loop;

  if v_count <> array_length(p_listing_ids, 1) then
    raise exception 'one or more listings could not be found'
      using errcode = 'check_violation';
  end if;

  update public.orders set total_price = v_total where id = v_order;

  return v_order;
end;
$$;

-- ---------------------------------------------------------------------------
-- Responding to an order line
-- ---------------------------------------------------------------------------

create or replace function public.respond_to_order_line(
  p_line_id uuid,
  p_accept  boolean
)
returns void
language plpgsql
-- SECURITY DEFINER for the same reason: order_lines has no update policy, so this
-- is the only path to answering one. It verifies the caller is the farmer named on
-- the line before it changes anything.
security definer
set search_path = ''
as $$
declare
  v_line record;
begin
  select ol.*, o.confirmation_deadline
    into v_line
  from public.order_lines ol
  join public.orders o on o.id = ol.order_id
  where ol.id = p_line_id
  for update;

  if not found then
    raise exception 'order line not found' using errcode = 'insufficient_privilege';
  end if;

  if v_line.farmer_id <> auth.uid() then
    raise exception 'only the farmer on this line may answer it'
      using errcode = 'insufficient_privilege';
  end if;

  if v_line.status <> 'pending' then
    raise exception 'this line has already been answered' using errcode = 'check_violation';
  end if;

  if now() > v_line.confirmation_deadline then
    raise exception 'the confirmation window has closed' using errcode = 'check_violation';
  end if;

  update public.order_lines
     set status = case when p_accept then 'confirmed' else 'declined' end::public.order_line_status,
         responded_at = now()
   where id = p_line_id;

  -- A declined line releases the listing so it can be offered again.
  if not p_accept then
    update public.produce_listings
       set status = 'active'
     where id = v_line.listing_id;
  end if;

  perform public.refresh_order_status(v_line.order_id);
end;
$$;

-- The order's status is a summary of its lines, never set independently.
create or replace function public.refresh_order_status(p_order_id uuid)
returns void
language plpgsql
security definer          -- summarises lines the caller may not all see
set search_path = ''
as $$
declare
  v_total int; v_pending int; v_confirmed int;
begin
  select count(*),
         count(*) filter (where status = 'pending'),
         count(*) filter (where status = 'confirmed')
    into v_total, v_pending, v_confirmed
  from public.order_lines
  where order_id = p_order_id;

  update public.orders
     set status = case
       when v_pending > 0                      then 'pending'
       when v_confirmed = v_total              then 'confirmed'
       when v_confirmed = 0                    then 'declined'
       else                                         'partial'
     end::public.order_status
   where id = p_order_id
     and status <> 'cancelled';
end;
$$;

-- ---------------------------------------------------------------------------
-- Lapsing
-- ---------------------------------------------------------------------------
--
-- FR-8: an unanswered reservation lapses. Written as a callable function so it can
-- be scheduled (pg_cron in a deployed environment) and also invoked opportunistically
-- before a read, so a lapsed reservation is never *displayed* as still pending even
-- if no scheduler has run.
create or replace function public.expire_lapsed_reservations()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_expired int;
begin
  with lapsed as (
    update public.order_lines ol
       set status = 'lapsed', responded_at = now()
      from public.orders o
     where o.id = ol.order_id
       and ol.status = 'pending'
       and now() > o.confirmation_deadline
    returning ol.listing_id, ol.order_id
  ),
  released as (
    update public.produce_listings l
       set status = 'active'
      from lapsed
     where l.id = lapsed.listing_id
       and l.status = 'committed'
    returning 1
  )
  select count(*) into v_expired from lapsed;

  -- Recompute the affected orders.
  update public.orders o
     set status = case
       when x.pending > 0        then 'pending'
       when x.confirmed = x.total then 'confirmed'
       when x.confirmed = 0      then 'declined'
       else                           'partial'
     end::public.order_status
    from (
      select order_id,
             count(*) as total,
             count(*) filter (where status = 'pending')   as pending,
             count(*) filter (where status = 'confirmed') as confirmed
      from public.order_lines
      group by order_id
    ) x
   where o.id = x.order_id
     and o.status not in ('cancelled', 'confirmed', 'declined', 'partial');

  return v_expired;
end;
$$;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

create trigger orders_touch_updated_at
  before update on public.orders
  for each row execute function public.touch_updated_at();

create trigger orders_audit
  after insert or update or delete on public.orders
  for each row execute function public.audit_row_change();

create trigger order_lines_audit
  after insert or update or delete on public.order_lines
  for each row execute function public.audit_row_change();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.orders enable row level security;
alter table public.order_lines enable row level security;

create policy "buyer reads own orders"
  on public.orders for select to authenticated
  using ((select auth.uid()) = buyer_id);

-- A farmer sees an order only because one of their listings is on it, and only
-- that much: the order is the buyer's, not theirs.
create policy "farmer reads orders touching their listings"
  on public.orders for select to authenticated
  using (exists (
    select 1 from public.order_lines ol
    where ol.order_id = orders.id and ol.farmer_id = (select auth.uid())
  ));

create policy "compliance and admin read orders"
  on public.orders for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

-- No insert policy, deliberately. Orders are created only by place_order(), which
-- holds the reservation invariants; a direct insert would let a buyer skip them.
create policy "buyer cancels own pending order"
  on public.orders for update to authenticated
  using ((select auth.uid()) = buyer_id and status = 'pending')
  with check ((select auth.uid()) = buyer_id);

create policy "buyer reads own order lines"
  on public.order_lines for select to authenticated
  using ((select auth.uid()) = buyer_id);

create policy "farmer reads own order lines"
  on public.order_lines for select to authenticated
  using ((select auth.uid()) = farmer_id);

create policy "compliance and admin read order lines"
  on public.order_lines for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

-- Lines are written by place_order() and answered by respond_to_order_line(),
-- both of which check the caller. No direct write policy.
