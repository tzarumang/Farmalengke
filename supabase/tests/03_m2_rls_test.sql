-- M2 row-level security and constraint tests: farms and produce listings.
--
-- Same posture as 02: anything that should be refused is asserted to actually
-- raise or return zero rows.

\set ON_ERROR_STOP on
\timing off
\pset pager off

begin;

insert into auth.users (id, phone) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '+639171110001'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '+639171110002'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '+639171110003'),
  ('aaaaaaaa-0000-0000-0000-000000000004', '+639171110004'),
  ('aaaaaaaa-0000-0000-0000-000000000005', '+639171110005');

insert into public.user_roles (user_id, role, granted_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'farmer',       null),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'farmer',       null),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'buyer',        null),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'trading_desk', null),
  ('aaaaaaaa-0000-0000-0000-000000000005', 'compliance',   null);

insert into public.profiles (id, mobile_number, display_name) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '+639171110001', 'Farmer One'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '+639171110002', 'Farmer Two'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '+639171110003', 'Buyer'),
  ('aaaaaaaa-0000-0000-0000-000000000004', '+639171110004', 'Trading Desk'),
  ('aaaaaaaa-0000-0000-0000-000000000005', '+639171110005', 'Compliance');

create or replace function pg_temp.claims_for(p_user uuid)
returns text language sql as $$
  select jsonb_build_object(
    'sub', p_user::text,
    'role', 'authenticated',
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
  v_claims := pg_temp.claims_for(p_user);   -- built as owner, before dropping role
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims = %L', v_claims);
end $$;

create or replace procedure pg_temp.ok(c boolean, label text)
language plpgsql as $$
begin
  if c then raise notice '  PASS  %', label;
  else raise exception 'FAIL  %', label; end if;
end $$;

-- RLS filters non-matching rows out of an UPDATE or DELETE rather than raising.
-- Silence is the correct behaviour there, so the assertion is "nothing changed",
-- not "it threw".
create or replace procedure pg_temp.changes_nothing(p_sql text, label text)
language plpgsql as $$
declare n int;
begin
  execute p_sql;
  get diagnostics n = row_count;
  if n = 0 then
    raise notice '  PASS  % (0 rows affected)', label;
  else
    raise exception 'FAIL  % -- % row(s) were changed', label, n;
  end if;
end $$;

create or replace procedure pg_temp.denied(p_sql text, label text)
language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    raise notice '  PASS  % (refused: %)', label, replace(sqlerrm, E'\n', ' ');
    return;
  end;
  raise exception 'FAIL  % -- the statement was ALLOWED and should not have been', label;
end $$;

\echo ''
\echo '=== reference data is seeded and readable ==='

do $$
declare n int;
begin
  select count(*) into n from public.regions;
  call pg_temp.ok(n = 2, 'both regions seeded (got ' || n || ')');
  select count(*) into n from public.commodities;
  call pg_temp.ok(n = 9, 'nine commodities seeded across both regions (got ' || n || ')');
  select count(*) into n from public.region_commodities where region_code = 'PH-CAR';
  call pg_temp.ok(n = 5, 'Cordillera has 5 commodities (got ' || n || ')');
  select count(*) into n from public.region_commodities where region_code = 'PH-R03';
  call pg_temp.ok(n = 5, 'Central Luzon has 5 commodities (got ' || n || ')');
end $$;

\echo ''
\echo '=== a farmer cannot rewrite a unit conversion (it decides what they are paid) ==='

do $$
begin
  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000001');
  call pg_temp.changes_nothing(
    $q$update public.commodity_units set kilograms_per_unit = 999$q$,
    'farmer cannot alter a kilogram conversion');
  call pg_temp.denied(
    $q$insert into public.commodities (code, name_en, name_fil) values ('fake','Fake','Peke')$q$,
    'farmer cannot invent a commodity');
end $$;
reset role;

-- The assertion above is that no row changed. Confirm the stored value really is
-- untouched, since "0 rows affected" and "the data is still right" are not the
-- same claim.
do $$
declare v numeric;
begin
  select kilograms_per_unit into v
  from public.commodity_units cu
  join public.commodities c on c.id = cu.commodity_id
  where c.code = 'cabbage' and cu.unit_code = 'kg';
  call pg_temp.ok(v = 1.000, 'the kilogram conversion is still 1.000, not 999 (got ' || v || ')');
end $$;

\echo ''
\echo '=== farms: GPS requires recorded consent ==='

do $$
declare v_farm uuid;
begin
  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000001');

  call pg_temp.denied(
    $q$insert into public.farms
         (farmer_id, name, region_code, barangay, city_municipality, province,
          gps_latitude, gps_longitude)
       values ('aaaaaaaa-0000-0000-0000-000000000001','Sneaky','PH-CAR','San Isidro',
               'La Trinidad','Benguet', 16.45, 120.59)$q$,
    'coordinates without recorded consent are rejected');

  insert into public.farms
    (farmer_id, name, region_code, barangay, city_municipality, province,
     area_value, area_unit)
  values ('aaaaaaaa-0000-0000-0000-000000000001','Upper Field','PH-CAR','San Isidro',
          'La Trinidad','Benguet', 0.5, 'hectare')
  returning id into v_farm;
  call pg_temp.ok(v_farm is not null, 'a farm with barangay-level location only is accepted');

  call pg_temp.denied(
    $q$insert into public.farms (farmer_id, name, region_code, barangay,
          city_municipality, province, area_value)
       values ('aaaaaaaa-0000-0000-0000-000000000001','Bad area','PH-CAR','San Isidro',
               'La Trinidad','Benguet', 2)$q$,
    'an area value with no unit is rejected');
end $$;
reset role;

\echo ''
\echo '=== farms: one farmer cannot see or touch another farmer''s farm ==='

do $$
declare n int;
begin
  -- Seed a second farmer's farm as owner.
  reset role;
  insert into public.farms (farmer_id, name, region_code, barangay, city_municipality, province)
  values ('aaaaaaaa-0000-0000-0000-000000000002','Other Field','PH-R03','Bagong Silang',
          'Cabanatuan','Nueva Ecija');

  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000001');
  select count(*) into n from public.farms;
  call pg_temp.ok(n = 1, 'farmer one sees only their own farm (got ' || n || ')');

  update public.farms set name = 'hijacked'
   where farmer_id = 'aaaaaaaa-0000-0000-0000-000000000002';
  get diagnostics n = row_count;
  call pg_temp.ok(n = 0, 'farmer one''s update of another farm affects 0 rows');
end $$;
reset role;

\echo ''
\echo '=== farms: the trading desk does not get a map of where farmers live ==='

do $$
declare n int;
begin
  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000004');
  select count(*) into n from public.farms;
  call pg_temp.ok(n = 0, 'the trading desk reads no farms (got ' || n || ')');
  reset role;

  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000005');
  select count(*) into n from public.farms;
  call pg_temp.ok(n = 2, 'compliance reads all farms (got ' || n || ')');
end $$;
reset role;

\echo ''
\echo '=== listings: quantity is normalised to kilograms, and refused when unknown ==='

do $$
declare v_farm uuid; v_kg numeric; v_listing uuid;
begin
  select id into v_farm from public.farms
   where farmer_id = 'aaaaaaaa-0000-0000-0000-000000000001';

  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000001');

  insert into public.produce_listings
    (farmer_id, farm_id, commodity_id, quantity, unit_code, availability, status)
  values ('aaaaaaaa-0000-0000-0000-000000000001', v_farm,
          (select id from public.commodities where code = 'cabbage'),
          120, 'kg', 'available_now', 'active')
  returning id into v_listing;

  reset role;
  select quantity_kg into v_kg from public.produce_listings where id = v_listing;
  call pg_temp.ok(v_kg = 120.000, '120 kg of cabbage stores as 120 kg (got ' || v_kg || ')');

  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000001');
  -- No sako conversion is seeded on purpose: inventing one would put an unsourced
  -- weight in front of a farmer. The write must fail loudly rather than guess.
  call pg_temp.denied(
    format($q$insert into public.produce_listings
              (farmer_id, farm_id, commodity_id, quantity, unit_code, availability)
            values ('aaaaaaaa-0000-0000-0000-000000000001', %L,
                    (select id from public.commodities where code = 'cabbage'),
                    3, 'sako', 'available_now')$q$, v_farm),
    'a unit with no recorded kilogram conversion is refused, not guessed');
end $$;
reset role;

\echo ''
\echo '=== listings: must reference the farmer''s own farm ==='

do $$
declare v_other_farm uuid;
begin
  select id into v_other_farm from public.farms
   where farmer_id = 'aaaaaaaa-0000-0000-0000-000000000002';

  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$insert into public.produce_listings
              (farmer_id, farm_id, commodity_id, quantity, unit_code, availability)
            values ('aaaaaaaa-0000-0000-0000-000000000001', %L,
                    (select id from public.commodities where code = 'cabbage'),
                    10, 'kg', 'available_now')$q$, v_other_farm),
    'a farmer cannot list produce against somebody else''s farm');
end $$;
reset role;

\echo ''
\echo '=== listings: expected harvest needs a date ==='

do $$
declare v_farm uuid;
begin
  select id into v_farm from public.farms
   where farmer_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$insert into public.produce_listings
              (farmer_id, farm_id, commodity_id, quantity, unit_code, availability)
            values ('aaaaaaaa-0000-0000-0000-000000000001', %L,
                    (select id from public.commodities where code = 'carrot'),
                    50, 'kg', 'expected')$q$, v_farm),
    'an expected listing with no availability date is rejected');
end $$;
reset role;

\echo ''
\echo '=== listings: buyers see what is offered, never a farmer''s draft ==='

do $$
declare v_farm uuid; n int;
begin
  select id into v_farm from public.farms
   where farmer_id = 'aaaaaaaa-0000-0000-0000-000000000001';

  insert into public.produce_listings
    (farmer_id, farm_id, commodity_id, quantity, unit_code, availability, status)
  values ('aaaaaaaa-0000-0000-0000-000000000001', v_farm,
          (select id from public.commodities where code = 'potato'),
          40, 'kg', 'available_now', 'draft');

  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000003');
  select count(*) into n from public.produce_listings;
  call pg_temp.ok(n = 1, 'the buyer sees the 1 active listing, not the draft (got ' || n || ')');

  select count(*) into n from public.produce_listings where status = 'draft';
  call pg_temp.ok(n = 0, 'the buyer cannot see a draft listing');
  reset role;

  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000002');
  select count(*) into n from public.produce_listings;
  call pg_temp.ok(n = 0, 'another farmer sees neither (got ' || n || ')');
end $$;
reset role;

\echo ''
\echo '=== listings: a committed listing cannot be edited out from under a buyer ==='

do $$
declare v_listing uuid; n int;
begin
  select id into v_listing from public.produce_listings where status = 'active' limit 1;
  update public.produce_listings set status = 'committed' where id = v_listing;

  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000001');
  update public.produce_listings set quantity = 1 where id = v_listing;
  get diagnostics n = row_count;
  call pg_temp.ok(n = 0, 'the farmer''s edit of a committed listing affects 0 rows');
end $$;
reset role;

\echo ''
\echo '=== offline sync is idempotent, not duplicating ==='

do $$
declare v_farm uuid; v_ref uuid := gen_random_uuid();
begin
  select id into v_farm from public.farms
   where farmer_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  call pg_temp.become('aaaaaaaa-0000-0000-0000-000000000001');

  insert into public.produce_listings
    (farmer_id, farm_id, commodity_id, quantity, unit_code, availability, client_reference)
  values ('aaaaaaaa-0000-0000-0000-000000000001', v_farm,
          (select id from public.commodities where code = 'tomato'),
          25, 'kg', 'available_now', v_ref);

  call pg_temp.denied(
    format($q$insert into public.produce_listings
              (farmer_id, farm_id, commodity_id, quantity, unit_code, availability, client_reference)
            values ('aaaaaaaa-0000-0000-0000-000000000001', %L,
                    (select id from public.commodities where code = 'tomato'),
                    25, 'kg', 'available_now', %L)$q$, v_farm, v_ref),
    'the same offline record syncing twice cannot create a duplicate');
end $$;
reset role;

\echo ''
\echo '=== every change was audited ==='

do $$
declare n int;
begin
  select count(*) into n from public.audit_log where entity_table = 'farms';
  call pg_temp.ok(n > 0, 'farm changes were audit-logged (' || n || ' entries)');
  select count(*) into n from public.audit_log where entity_table = 'produce_listings';
  call pg_temp.ok(n > 0, 'listing changes were audit-logged (' || n || ' entries)');
end $$;

rollback;

\echo ''
\echo 'All M2 tests passed.'
