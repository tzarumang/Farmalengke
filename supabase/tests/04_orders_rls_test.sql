-- M2 slice 2: pricing, browse eligibility, and order reservations.
--
-- The reservation logic is the riskiest part of this milestone, so the double-sell,
-- confirmation-window, and lapsing paths are all exercised rather than assumed.

\set ON_ERROR_STOP on
\timing off
\pset pager off

begin;

insert into auth.users (id, phone) values
  ('bbbbbbbb-0000-0000-0000-000000000001', '+639172220001'),  -- farmer one
  ('bbbbbbbb-0000-0000-0000-000000000002', '+639172220002'),  -- farmer two
  ('bbbbbbbb-0000-0000-0000-000000000003', '+639172220003'),  -- buyer one
  ('bbbbbbbb-0000-0000-0000-000000000004', '+639172220004'),  -- buyer two
  ('bbbbbbbb-0000-0000-0000-000000000005', '+639172220005');  -- trading desk

insert into public.user_roles (user_id, role, granted_by) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'farmer',       null),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'farmer',       null),
  ('bbbbbbbb-0000-0000-0000-000000000003', 'buyer',        null),
  ('bbbbbbbb-0000-0000-0000-000000000004', 'buyer',        null),
  ('bbbbbbbb-0000-0000-0000-000000000005', 'trading_desk', null);

insert into public.profiles (id, mobile_number, display_name) values
  ('bbbbbbbb-0000-0000-0000-000000000001', '+639172220001', 'Farmer One'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '+639172220002', 'Farmer Two'),
  ('bbbbbbbb-0000-0000-0000-000000000003', '+639172220003', 'Buyer One'),
  ('bbbbbbbb-0000-0000-0000-000000000004', '+639172220004', 'Buyer Two'),
  ('bbbbbbbb-0000-0000-0000-000000000005', '+639172220005', 'Trading Desk');

insert into public.farms (id, farmer_id, name, region_code, barangay, city_municipality, province) values
  ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001',
   'Farm One', 'PH-CAR', 'San Isidro', 'La Trinidad', 'Benguet'),
  ('cccccccc-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002',
   'Farm Two', 'PH-CAR', 'Betag', 'La Trinidad', 'Benguet');

create or replace function pg_temp.claims_for(p_user uuid)
returns text language sql as $$
  select jsonb_build_object(
    'sub', p_user::text, 'role', 'authenticated',
    'app_metadata', jsonb_build_object(
      'roles', coalesce((select jsonb_agg(to_jsonb(ur.role::text))
                           from public.user_roles ur
                          where ur.user_id = p_user and ur.revoked_at is null),
                        '[]'::jsonb))
  )::text;
$$;

create or replace procedure pg_temp.become(p_user uuid)
language plpgsql as $$
declare v_claims text;
begin
  v_claims := pg_temp.claims_for(p_user);
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims = %L', v_claims);
end $$;

create or replace procedure pg_temp.ok(c boolean, label text)
language plpgsql as $$
begin
  if c then raise notice '  PASS  %', label;
  else raise exception 'FAIL  %', label; end if;
end $$;

create or replace procedure pg_temp.denied(p_sql text, label text)
language plpgsql as $$
begin
  begin execute p_sql;
  exception when others then
    raise notice '  PASS  % (refused: %)', label, replace(sqlerrm, E'\n', ' ');
    return;
  end;
  raise exception 'FAIL  % -- the statement was ALLOWED and should not have been', label;
end $$;

-- A listing, offered at a price.
create or replace function pg_temp.new_listing(
  p_farmer uuid, p_farm uuid, p_code text, p_qty numeric, p_price numeric,
  p_status public.listing_status default 'active')
returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into public.produce_listings
    (farmer_id, farm_id, commodity_id, quantity, unit_code, availability,
     asking_price, status)
  values (p_farmer, p_farm,
          (select id from public.commodities where code = p_code),
          p_qty, 'kg', 'available_now', p_price, p_status)
  returning id into v_id;
  return v_id;
end $$;

\echo ''
\echo '=== FR-9: only the trading desk publishes prices, in its own name ==='

do $$
declare v_cabbage uuid;
begin
  select id into v_cabbage from public.commodities where code = 'cabbage';

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$insert into public.platform_prices
              (commodity_id, region_code, price_per_kg, created_by)
            values (%L,'PH-CAR', 25, 'bbbbbbbb-0000-0000-0000-000000000001')$q$, v_cabbage),
    'a farmer cannot publish a platform price');
  reset role;

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000005');
  call pg_temp.denied(
    format($q$insert into public.platform_prices
              (commodity_id, region_code, price_per_kg, created_by)
            values (%L,'PH-CAR', 25, 'bbbbbbbb-0000-0000-0000-000000000001')$q$, v_cabbage),
    'the trading desk cannot publish a price attributed to somebody else');

  insert into public.platform_prices (commodity_id, region_code, price_per_kg, created_by)
  values (v_cabbage, 'PH-CAR', 25, 'bbbbbbbb-0000-0000-0000-000000000005');
  call pg_temp.ok(true, 'the trading desk CAN publish a price in its own name');
end $$;
reset role;

\echo ''
\echo '=== FR-9: a published price is history and cannot be rewritten ==='

do $$
begin
  call pg_temp.denied($q$update public.platform_prices set price_per_kg = 1$q$,
                      'even the table OWNER cannot edit a published price');
  call pg_temp.denied($q$delete from public.platform_prices$q$,
                      'even the table OWNER cannot delete a published price');
end $$;

\echo ''
\echo '=== FR-9: a future price is not visible to farmers until it takes effect ==='

do $$
declare v_cabbage uuid; n int; v numeric;
begin
  select id into v_cabbage from public.commodities where code = 'cabbage';
  insert into public.platform_prices
    (commodity_id, region_code, price_per_kg, effective_from, created_by)
  values (v_cabbage, 'PH-CAR', 40, now() + interval '2 days',
          'bbbbbbbb-0000-0000-0000-000000000005');

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000001');
  select count(*) into n from public.platform_prices;
  call pg_temp.ok(n = 1, 'the farmer sees only the price in force, not tomorrow''s (got ' || n || ')');
  reset role;

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000005');
  select count(*) into n from public.platform_prices;
  call pg_temp.ok(n = 2, 'the trading desk sees its own scheduled price (got ' || n || ')');
  reset role;

  select public.current_platform_price(v_cabbage, 'PH-CAR') into v;
  call pg_temp.ok(v = 25, 'the current price is today''s 25, not the scheduled 40 (got ' || v || ')');

  select public.current_platform_price(v_cabbage, 'PH-CAR', now() + interval '3 days') into v;
  call pg_temp.ok(v = 40, 'in three days the scheduled 40 is in force (got ' || v || ')');
end $$;
reset role;

\echo ''
\echo '=== a listing cannot be offered to buyers without a price ==='

do $$
declare v_farm uuid := 'cccccccc-0000-0000-0000-000000000001'::uuid;
begin
  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000001');
  call pg_temp.denied(
    $q$insert into public.produce_listings
         (farmer_id, farm_id, commodity_id, quantity, unit_code, availability, status)
       values ('bbbbbbbb-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001',
               (select id from public.commodities where code='cabbage'),
               10,'kg','available_now','active')$q$,
    'an active listing with no asking price is rejected');
end $$;
reset role;

\echo ''
\echo '=== FR-8: placing an order reserves the listing and snapshots the price ==='

do $$
declare v_listing uuid; v_order uuid; v_total numeric; v_status public.listing_status;
begin
  v_listing := pg_temp.new_listing('bbbbbbbb-0000-0000-0000-000000000001',
                                   'cccccccc-0000-0000-0000-000000000001',
                                   'cabbage', 100, 30);

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000003');
  v_order := public.place_order(array[v_listing], current_date + 3,
                                'Poblacion', 'Baguio', 'Benguet');
  reset role;

  select total_price into v_total from public.orders where id = v_order;
  call pg_temp.ok(v_total = 3000.00, '100 kg at 30 gives a total of 3000 (got ' || v_total || ')');

  select status into v_status from public.produce_listings where id = v_listing;
  call pg_temp.ok(v_status = 'committed', 'the listing is reserved (got ' || v_status || ')');
end $$;
reset role;

\echo ''
\echo '=== FR-8: the same listing cannot be sold twice ==='

do $$
declare v_listing uuid;
begin
  select ol.listing_id into v_listing from public.order_lines ol limit 1;

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000004');
  call pg_temp.denied(
    format($q$select public.place_order(array[%L]::uuid[], current_date + 3,
                                        'Poblacion','Baguio','Benguet')$q$, v_listing),
    'a second buyer cannot order a listing already reserved');
end $$;
reset role;

\echo ''
\echo '=== FR-8: only a buyer places orders ==='

do $$
declare v_listing uuid;
begin
  v_listing := pg_temp.new_listing('bbbbbbbb-0000-0000-0000-000000000002',
                                   'cccccccc-0000-0000-0000-000000000002',
                                   'potato', 50, 20);
  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$select public.place_order(array[%L]::uuid[], current_date + 3,
                                        'Poblacion','Baguio','Benguet')$q$, v_listing),
    'a farmer cannot place an order');
end $$;
reset role;

\echo ''
\echo '=== FR-8: only the farmer on a line may answer it ==='

do $$
declare v_line uuid;
begin
  select id into v_line from public.order_lines where status = 'pending' limit 1;

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000002');
  call pg_temp.denied(
    format($q$select public.respond_to_order_line(%L, true)$q$, v_line),
    'another farmer cannot confirm somebody else''s line');
  reset role;

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000003');
  call pg_temp.denied(
    format($q$select public.respond_to_order_line(%L, true)$q$, v_line),
    'the buyer cannot confirm on the farmer''s behalf');
end $$;
reset role;

\echo ''
\echo '=== FR-8: declining releases the listing back to the market ==='

do $$
declare v_line uuid; v_listing uuid; v_status public.listing_status; v_order uuid;
        v_order_status public.order_status;
begin
  select id, listing_id, order_id into v_line, v_listing, v_order
  from public.order_lines where status = 'pending' limit 1;

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000001');
  perform public.respond_to_order_line(v_line, false);
  reset role;

  select status into v_status from public.produce_listings where id = v_listing;
  call pg_temp.ok(v_status = 'active', 'the declined listing is offered again (got ' || v_status || ')');

  select status into v_order_status from public.orders where id = v_order;
  call pg_temp.ok(v_order_status = 'declined', 'the order reads as declined (got ' || v_order_status || ')');
end $$;
reset role;

\echo ''
\echo '=== FR-8: confirming holds the reservation ==='

do $$
declare v_listing uuid; v_order uuid; v_line uuid;
        v_ls public.listing_status; v_os public.order_status;
begin
  v_listing := pg_temp.new_listing('bbbbbbbb-0000-0000-0000-000000000001',
                                   'cccccccc-0000-0000-0000-000000000001',
                                   'carrot', 80, 45);

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000003');
  v_order := public.place_order(array[v_listing], current_date + 5,
                                'Poblacion','Baguio','Benguet');
  reset role;

  select id into v_line from public.order_lines where order_id = v_order;

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000001');
  perform public.respond_to_order_line(v_line, true);
  reset role;

  select status into v_ls from public.produce_listings where id = v_listing;
  select status into v_os from public.orders where id = v_order;
  call pg_temp.ok(v_ls = 'committed', 'a confirmed listing stays reserved (got ' || v_ls || ')');
  call pg_temp.ok(v_os = 'confirmed', 'the order reads as confirmed (got ' || v_os || ')');
end $$;
reset role;

\echo ''
\echo '=== FR-8: an unanswered reservation lapses and frees the listing ==='

do $$
declare v_listing uuid; v_order uuid; v_expired int;
        v_ls public.listing_status; v_line_status public.order_line_status;
begin
  v_listing := pg_temp.new_listing('bbbbbbbb-0000-0000-0000-000000000002',
                                   'cccccccc-0000-0000-0000-000000000002',
                                   'chayote', 60, 15);

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000003');
  v_order := public.place_order(array[v_listing], current_date + 4,
                                'Poblacion','Baguio','Benguet');
  reset role;

  -- Wind the deadline back rather than waiting 24 hours.
  update public.orders set confirmation_deadline = now() - interval '1 minute'
   where id = v_order;

  select public.expire_lapsed_reservations() into v_expired;
  call pg_temp.ok(v_expired >= 1, 'the expiry sweep lapsed the reservation (got ' || v_expired || ')');

  select status into v_line_status from public.order_lines where order_id = v_order;
  call pg_temp.ok(v_line_status = 'lapsed', 'the line reads as lapsed (got ' || v_line_status || ')');

  select status into v_ls from public.produce_listings where id = v_listing;
  call pg_temp.ok(v_ls = 'active', 'the lapsed listing is offered again (got ' || v_ls || ')');
end $$;
reset role;

\echo ''
\echo '=== FR-8: a farmer cannot answer after the window has closed ==='

do $$
declare v_listing uuid; v_order uuid; v_line uuid;
begin
  v_listing := pg_temp.new_listing('bbbbbbbb-0000-0000-0000-000000000001',
                                   'cccccccc-0000-0000-0000-000000000001',
                                   'tomato', 30, 55);
  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000003');
  v_order := public.place_order(array[v_listing], current_date + 2,
                                'Poblacion','Baguio','Benguet');
  reset role;

  update public.orders set confirmation_deadline = now() - interval '1 minute'
   where id = v_order;
  select id into v_line from public.order_lines where order_id = v_order;

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$select public.respond_to_order_line(%L, true)$q$, v_line),
    'confirming after the window closes is refused');
end $$;
reset role;

\echo ''
\echo '=== orders are visible to their own parties, and nobody else ==='

do $$
declare n int;
begin
  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000003');
  select count(*) into n from public.orders;
  call pg_temp.ok(n = 4, 'buyer one sees the 4 orders they placed (got ' || n || ')');
  reset role;

  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000004');
  select count(*) into n from public.orders;
  call pg_temp.ok(n = 0, 'buyer two sees none of buyer one''s orders (got ' || n || ')');
  reset role;

  -- Farmer two supplied one lapsed line, so sees exactly that order.
  call pg_temp.become('bbbbbbbb-0000-0000-0000-000000000002');
  select count(*) into n from public.orders;
  call pg_temp.ok(n = 1, 'farmer two sees only the order touching their listing (got ' || n || ')');

  select count(*) into n from public.order_lines;
  call pg_temp.ok(n = 1, 'and only their own line on it (got ' || n || ')');
end $$;
reset role;

\echo ''
\echo '=== everything was audited ==='

do $$
declare n int;
begin
  select count(*) into n from public.audit_log where entity_table = 'orders';
  call pg_temp.ok(n > 0, 'orders were audit-logged (' || n || ' entries)');
  select count(*) into n from public.audit_log where entity_table = 'platform_prices';
  call pg_temp.ok(n > 0, 'price publications were audit-logged (' || n || ' entries)');
end $$;

rollback;

\echo ''
\echo 'All order tests passed.'
