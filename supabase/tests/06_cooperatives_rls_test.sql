-- M2 slice 4: cooperatives, consolidated listings, and the verification ceiling
-- on a group sale.

\set ON_ERROR_STOP on
\timing off
\pset pager off

begin;

insert into auth.users (id, phone) values
  ('ffffffff-0000-0000-0000-000000000001', '+639174440001'),  -- officer
  ('ffffffff-0000-0000-0000-000000000002', '+639174440002'),  -- member, verified
  ('ffffffff-0000-0000-0000-000000000003', '+639174440003'),  -- member, UNVERIFIED
  ('ffffffff-0000-0000-0000-000000000004', '+639174440004'),  -- outsider farmer
  ('ffffffff-0000-0000-0000-000000000005', '+639174440005'),  -- buyer
  ('ffffffff-0000-0000-0000-000000000006', '+639174440006');  -- compliance

insert into public.user_roles (user_id, role, granted_by) values
  ('ffffffff-0000-0000-0000-000000000001', 'coop_officer', null),
  ('ffffffff-0000-0000-0000-000000000001', 'farmer',       null),
  ('ffffffff-0000-0000-0000-000000000002', 'farmer',       null),
  ('ffffffff-0000-0000-0000-000000000003', 'farmer',       null),
  ('ffffffff-0000-0000-0000-000000000004', 'farmer',       null),
  ('ffffffff-0000-0000-0000-000000000005', 'buyer',        null),
  ('ffffffff-0000-0000-0000-000000000006', 'compliance',   null);

insert into public.profiles (id, mobile_number, display_name, kyc_tier) values
  ('ffffffff-0000-0000-0000-000000000001', '+639174440001', 'Officer',    'tier_2'),
  ('ffffffff-0000-0000-0000-000000000002', '+639174440002', 'Verified',   'tier_2'),
  ('ffffffff-0000-0000-0000-000000000003', '+639174440003', 'Unverified', 'tier_0'),
  ('ffffffff-0000-0000-0000-000000000004', '+639174440004', 'Outsider',   'tier_2'),
  ('ffffffff-0000-0000-0000-000000000005', '+639174440005', 'Buyer',      'tier_2'),
  ('ffffffff-0000-0000-0000-000000000006', '+639174440006', 'Compliance', 'tier_2');

insert into public.farms (id, farmer_id, name, region_code, barangay, city_municipality, province)
values ('11111111-2222-0000-0000-000000000001', 'ffffffff-0000-0000-0000-000000000001',
        'Officer Farm', 'PH-CAR', 'San Isidro', 'La Trinidad', 'Benguet'),
       -- The member has their own farm, so the next test is refused by the group
       -- rule rather than incidentally by farm ownership.
       ('11111111-2222-0000-0000-000000000002', 'ffffffff-0000-0000-0000-000000000002',
        'Member Farm', 'PH-CAR', 'Betag', 'La Trinidad', 'Benguet');

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

\echo ''
\echo '=== FR-4: a group has a named officer, who is a member from the start ==='

do $$
declare v_coop uuid; n int;
begin
  call pg_temp.become('ffffffff-0000-0000-0000-000000000001');

  call pg_temp.denied(
    $q$insert into public.cooperatives (name, officer_id, region_code, barangay,
          city_municipality, province)
       values ('Not mine','ffffffff-0000-0000-0000-000000000002','PH-CAR','X','Y','Z')$q$,
    'a group cannot be registered in somebody else''s name');

  insert into public.cooperatives (id, name, officer_id, region_code, barangay,
                                   city_municipality, province)
  values ('22222222-3333-0000-0000-000000000001', 'Benguet Growers',
          'ffffffff-0000-0000-0000-000000000001', 'PH-CAR', 'San Isidro',
          'La Trinidad', 'Benguet');
  reset role;

  select count(*) into n from public.cooperative_memberships
   where cooperative_id = '22222222-3333-0000-0000-000000000001' and status = 'active';
  call pg_temp.ok(n = 1, 'the officer is an active member from the start (got ' || n || ')');
end $$;
reset role;

\echo ''
\echo '=== FR-4: farmers join by invitation and must accept ==='

do $$
declare v_m2 uuid; v_m3 uuid; v_status public.membership_status;
begin
  call pg_temp.become('ffffffff-0000-0000-0000-000000000001');

  -- An officer cannot enrol somebody directly.
  call pg_temp.denied(
    $q$insert into public.cooperative_memberships
         (cooperative_id, farmer_id, status, invited_by, responded_at)
       values ('22222222-3333-0000-0000-000000000001',
               'ffffffff-0000-0000-0000-000000000002','active',
               'ffffffff-0000-0000-0000-000000000001', now())$q$,
    'an officer cannot add a member directly as active');

  insert into public.cooperative_memberships (cooperative_id, farmer_id, invited_by)
  values ('22222222-3333-0000-0000-000000000001',
          'ffffffff-0000-0000-0000-000000000002',
          'ffffffff-0000-0000-0000-000000000001')
  returning id into v_m2;

  insert into public.cooperative_memberships (cooperative_id, farmer_id, invited_by)
  values ('22222222-3333-0000-0000-000000000001',
          'ffffffff-0000-0000-0000-000000000003',
          'ffffffff-0000-0000-0000-000000000001')
  returning id into v_m3;
  reset role;

  -- The officer cannot answer on the farmer's behalf.
  call pg_temp.become('ffffffff-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$select public.respond_to_invitation(%L, true)$q$, v_m2),
    'the officer cannot accept an invitation for somebody else');
  reset role;

  call pg_temp.become('ffffffff-0000-0000-0000-000000000002');
  perform public.respond_to_invitation(v_m2, true);
  reset role;

  call pg_temp.become('ffffffff-0000-0000-0000-000000000003');
  perform public.respond_to_invitation(v_m3, true);
  reset role;

  select status into v_status from public.cooperative_memberships where id = v_m2;
  call pg_temp.ok(v_status = 'active', 'a farmer who accepts becomes active (got ' || v_status || ')');
end $$;
reset role;

\echo ''
\echo '=== FR-4: a member can leave, but the officer cannot walk away ==='

do $$
declare v_m uuid; v_officer_m uuid; v_status public.membership_status;
begin
  select id into v_officer_m from public.cooperative_memberships
   where farmer_id = 'ffffffff-0000-0000-0000-000000000001';

  call pg_temp.become('ffffffff-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$select public.leave_cooperative(%L)$q$, v_officer_m),
    'the officer cannot leave and orphan the group');
  reset role;

  -- Prove leaving works, then put the member back for the tests below.
  select id into v_m from public.cooperative_memberships
   where farmer_id = 'ffffffff-0000-0000-0000-000000000002';

  call pg_temp.become('ffffffff-0000-0000-0000-000000000002');
  perform public.leave_cooperative(v_m);
  reset role;

  select status into v_status from public.cooperative_memberships where id = v_m;
  call pg_temp.ok(v_status = 'left', 'a member can leave (got ' || v_status || ')');

  update public.cooperative_memberships
     set status = 'active', ended_at = null where id = v_m;
end $$;
reset role;

\echo ''
\echo '=== group listings: only the officer lists, only members contribute ==='

do $$
declare v_listing uuid;
begin
  call pg_temp.become('ffffffff-0000-0000-0000-000000000002');
  call pg_temp.denied(
    $q$insert into public.produce_listings
         (farmer_id, farm_id, commodity_id, quantity, unit_code, availability,
          asking_price, status, cooperative_id)
       values ('ffffffff-0000-0000-0000-000000000002','11111111-2222-0000-0000-000000000002',
               (select id from public.commodities where code='cabbage'),
               100,'kg','available_now',30,'draft','22222222-3333-0000-0000-000000000001')$q$,
    'an ordinary member cannot list on the group''s behalf');
  reset role;

  call pg_temp.become('ffffffff-0000-0000-0000-000000000001');
  insert into public.produce_listings
    (id, farmer_id, farm_id, commodity_id, quantity, unit_code, availability,
     asking_price, status, cooperative_id)
  values ('33333333-4444-0000-0000-000000000001',
          'ffffffff-0000-0000-0000-000000000001','11111111-2222-0000-0000-000000000001',
          (select id from public.commodities where code='cabbage'),
          300,'kg','available_now',30,'draft','22222222-3333-0000-0000-000000000001');
  call pg_temp.ok(true, 'the officer can list on the group''s behalf');

  call pg_temp.denied(
    $q$insert into public.listing_contributions (listing_id, farmer_id, quantity_kg)
       values ('33333333-4444-0000-0000-000000000001',
               'ffffffff-0000-0000-0000-000000000004', 50)$q$,
    'a non-member cannot be recorded as a contributor');
end $$;
reset role;

\echo ''
\echo '=== a group listing cannot be offered until the contributions add up ==='

do $$
begin
  call pg_temp.become('ffffffff-0000-0000-0000-000000000001');

  insert into public.listing_contributions (listing_id, farmer_id, quantity_kg) values
    ('33333333-4444-0000-0000-000000000001','ffffffff-0000-0000-0000-000000000001', 100),
    ('33333333-4444-0000-0000-000000000001','ffffffff-0000-0000-0000-000000000002', 100);

  call pg_temp.denied(
    $q$update public.produce_listings set status = 'active'
        where id = '33333333-4444-0000-0000-000000000001'$q$,
    '200 kg of contributions against a 300 kg listing is refused');

  insert into public.listing_contributions (listing_id, farmer_id, quantity_kg)
  values ('33333333-4444-0000-0000-000000000001','ffffffff-0000-0000-0000-000000000003', 100);

  update public.produce_listings set status = 'active'
   where id = '33333333-4444-0000-0000-000000000001';
  call pg_temp.ok(true, 'offered once the contributions match the listing');
end $$;
reset role;

\echo ''
\echo '=== THE BYPASS: an unverified member limits what the group can sell ==='

do $$
declare v_order uuid; v_line uuid; v_msg text;
begin
  -- 300 kg at 30 = 9000, split three ways = 3000 each. The unverified member
  -- cannot take 3000, so the whole sale is refused even though the officer who
  -- confirms it is fully verified.
  select public.group_ceiling_breach('33333333-4444-0000-0000-000000000001', 9000) into v_msg;
  call pg_temp.ok(v_msg is not null,
                  'a group sale is blocked when one member cannot take their share');
  call pg_temp.ok(v_msg ilike '%Unverified%',
                  'and the message names who: "' || left(v_msg, 70) || '..."');

  call pg_temp.become('ffffffff-0000-0000-0000-000000000005');
  v_order := public.place_order(array['33333333-4444-0000-0000-000000000001'::uuid],
                                current_date + 3, 'A', 'B', 'C');
  reset role;

  select id into v_line from public.order_lines where order_id = v_order;

  call pg_temp.become('ffffffff-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$select public.respond_to_order_line(%L, true)$q$, v_line),
    'the verified officer cannot confirm it either — no routing round verification');

  -- Declining still works, as it must.
  perform public.respond_to_order_line(v_line, false);
  call pg_temp.ok(true, 'and the officer can still decline');
end $$;
reset role;

\echo ''
\echo '=== once every member is verified, the same sale goes through ==='

do $$
declare v_order uuid; v_line uuid; v_status public.order_line_status;
begin
  call pg_temp.become('ffffffff-0000-0000-0000-000000000006');
  update public.profiles set kyc_tier = 'tier_2'
   where id = 'ffffffff-0000-0000-0000-000000000003';
  reset role;

  update public.produce_listings set status = 'active'
   where id = '33333333-4444-0000-0000-000000000001';

  call pg_temp.become('ffffffff-0000-0000-0000-000000000005');
  v_order := public.place_order(array['33333333-4444-0000-0000-000000000001'::uuid],
                                current_date + 3, 'A', 'B', 'C');
  reset role;

  select id into v_line from public.order_lines where order_id = v_order;

  call pg_temp.become('ffffffff-0000-0000-0000-000000000001');
  perform public.respond_to_order_line(v_line, true);
  reset role;

  select status into v_status from public.order_lines where id = v_line;
  call pg_temp.ok(v_status = 'confirmed', 'the sale confirms (got ' || v_status || ')');
end $$;
reset role;

\echo ''
\echo '=== FR-4: buyers see the breakdown; outsiders see nothing ==='

do $$
declare n int;
begin
  call pg_temp.become('ffffffff-0000-0000-0000-000000000005');
  select count(*) into n from public.listing_contributions;
  call pg_temp.ok(n = 3, 'the buyer sees all three contributions (got ' || n || ')');
  reset role;

  call pg_temp.become('ffffffff-0000-0000-0000-000000000004');
  select count(*) into n from public.listing_contributions;
  call pg_temp.ok(n = 0, 'an unrelated farmer sees none (got ' || n || ')');
  reset role;

  call pg_temp.become('ffffffff-0000-0000-0000-000000000002');
  select count(*) into n from public.listing_contributions;
  call pg_temp.ok(n = 1, 'a member sees their own contribution (got ' || n || ')');
end $$;
reset role;

\echo ''
\echo '=== identities stay separate from the group ==='

do $$
declare n int;
begin
  -- A member's own listings remain theirs; joining a group does not hand the
  -- officer any reach over them.
  call pg_temp.become('ffffffff-0000-0000-0000-000000000002');
  select count(*) into n from public.farms;
  call pg_temp.ok(n = 1,
                  'a member sees their own farm and not the officer''s (got ' || n || ')');
  reset role;

  select count(*) into n from public.listing_contributions
   where farmer_id = 'ffffffff-0000-0000-0000-000000000002';
  call pg_temp.ok(n = 1,
                  'each share is recorded against the member, not merged into the group');
end $$;
reset role;

rollback;

\echo ''
\echo 'All cooperative tests passed.'
