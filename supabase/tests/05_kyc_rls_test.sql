-- M2 slice 3: tiered identity verification and transaction ceilings.

\set ON_ERROR_STOP on
\timing off
\pset pager off

begin;

insert into auth.users (id, phone) values
  ('dddddddd-0000-0000-0000-000000000001', '+639173330001'),  -- farmer, unverified
  ('dddddddd-0000-0000-0000-000000000002', '+639173330002'),  -- buyer, tier 1
  ('dddddddd-0000-0000-0000-000000000003', '+639173330003'),  -- compliance
  ('dddddddd-0000-0000-0000-000000000004', '+639173330004'),  -- trading desk
  ('dddddddd-0000-0000-0000-000000000005', '+639173330005');  -- buyer, tier 2

insert into public.user_roles (user_id, role, granted_by) values
  ('dddddddd-0000-0000-0000-000000000001', 'farmer',       null),
  ('dddddddd-0000-0000-0000-000000000002', 'buyer',        null),
  ('dddddddd-0000-0000-0000-000000000003', 'compliance',   null),
  ('dddddddd-0000-0000-0000-000000000004', 'trading_desk', null),
  ('dddddddd-0000-0000-0000-000000000005', 'buyer',        null);

insert into public.profiles (id, mobile_number, display_name, kyc_tier) values
  ('dddddddd-0000-0000-0000-000000000001', '+639173330001', 'Unverified Farmer', 'tier_0'),
  ('dddddddd-0000-0000-0000-000000000002', '+639173330002', 'Tier 1 Buyer',      'tier_1'),
  ('dddddddd-0000-0000-0000-000000000003', '+639173330003', 'Compliance',        'tier_2'),
  ('dddddddd-0000-0000-0000-000000000004', '+639173330004', 'Trading Desk',      'tier_2'),
  ('dddddddd-0000-0000-0000-000000000005', '+639173330005', 'Tier 2 Buyer',      'tier_2');

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
\echo '=== FR-2: a blocked person is told what is needed, not just refused ==='

do $$
declare v_msg text;
begin
  -- tier_0
  select public.kyc_ceiling_breach('dddddddd-0000-0000-0000-000000000001', 100) into v_msg;
  call pg_temp.ok(v_msg is not null, 'an unverified account is blocked');
  call pg_temp.ok(v_msg ilike '%photo%',
                  'and is told a photo is the next step: "' || left(v_msg, 60) || '..."');

  -- tier_1, over the single-transaction ceiling (placeholder 10000)
  select public.kyc_ceiling_breach('dddddddd-0000-0000-0000-000000000002', 25000) into v_msg;
  call pg_temp.ok(v_msg is not null, 'tier 1 is blocked above the single-transaction ceiling');
  call pg_temp.ok(v_msg ilike '%government ID%',
                  'and is told which document raises it');

  -- tier_1, within the ceiling
  select public.kyc_ceiling_breach('dddddddd-0000-0000-0000-000000000002', 5000) into v_msg;
  call pg_temp.ok(v_msg is null, 'tier 1 is allowed below the ceiling');

  -- tier_2, comfortably within
  select public.kyc_ceiling_breach('dddddddd-0000-0000-0000-000000000005', 100000) into v_msg;
  call pg_temp.ok(v_msg is null, 'tier 2 is allowed a much larger amount');
end $$;

\echo ''
\echo '=== the ceilings are configuration, so answering Q6 is not a migration ==='

do $$
declare v_msg text;
begin
  update public.platform_settings set value = '3000'
   where key = 'kyc_tier_1_max_transaction_php';

  select public.kyc_ceiling_breach('dddddddd-0000-0000-0000-000000000002', 5000) into v_msg;
  call pg_temp.ok(v_msg is not null,
                  'lowering the setting immediately blocks what it previously allowed');

  update public.platform_settings set value = '10000'
   where key = 'kyc_tier_1_max_transaction_php';
end $$;

\echo ''
\echo '=== the rolling 30-day ceiling catches what a per-transaction one misses ==='

do $$
declare v_listing uuid; v_order uuid; v_msg text;
begin
  -- Give the tier 1 buyer a confirmed history just under the per-transaction cap.
  insert into public.farms (id, farmer_id, name, region_code, barangay, city_municipality, province)
  values ('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001',
          'KYC Farm', 'PH-CAR', 'San Isidro', 'La Trinidad', 'Benguet');

  insert into public.orders (buyer_id, delivery_date, delivery_barangay, delivery_city,
                             delivery_province, confirmation_deadline)
  values ('dddddddd-0000-0000-0000-000000000002', current_date + 1, 'X', 'Y', 'Z',
          now() + interval '1 day')
  returning id into v_order;

  insert into public.produce_listings
    (farmer_id, farm_id, commodity_id, quantity, unit_code, availability, asking_price, status)
  values ('dddddddd-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001',
          (select id from public.commodities where code = 'cabbage'),
          1, 'kg', 'available_now', 45000, 'committed')
  returning id into v_listing;

  insert into public.order_lines
    (order_id, listing_id, farmer_id, buyer_id, quantity_kg, price_per_kg, line_total,
     status, responded_at)
  values (v_order, v_listing, 'dddddddd-0000-0000-0000-000000000001',
          'dddddddd-0000-0000-0000-000000000002', 1, 45000, 45000, 'confirmed', now());

  call pg_temp.ok(public.transacted_last_30_days('dddddddd-0000-0000-0000-000000000002') = 45000,
                  'the 30-day total reflects the confirmed line');

  -- 8000 is under the 10000 per-transaction cap but takes the rolling total past 50000.
  select public.kyc_ceiling_breach('dddddddd-0000-0000-0000-000000000002', 8000) into v_msg;
  call pg_temp.ok(v_msg is not null,
                  'an amount under the per-transaction cap is still blocked by the 30-day total');
  call pg_temp.ok(v_msg ilike '%30 days%', 'and the message says why');
end $$;

\echo ''
\echo '=== an unverified farmer cannot accept an order ==='

do $$
declare v_listing uuid; v_order uuid; v_line uuid;
begin
  insert into public.produce_listings
    (farmer_id, farm_id, commodity_id, quantity, unit_code, availability, asking_price, status)
  values ('dddddddd-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001',
          (select id from public.commodities where code = 'potato'),
          10, 'kg', 'available_now', 20, 'active')
  returning id into v_listing;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000005');
  v_order := public.place_order(array[v_listing], current_date + 3, 'A', 'B', 'C');
  reset role;

  select id into v_line from public.order_lines where order_id = v_order;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$select public.respond_to_order_line(%L, true)$q$, v_line),
    'an unverified farmer cannot accept');

  -- Declining must always work: being unverified must never trap someone in a sale.
  perform public.respond_to_order_line(v_line, false);
  call pg_temp.ok(true, 'but an unverified farmer CAN decline');
end $$;
reset role;

\echo ''
\echo '=== an incomplete application is refused before review, not after ==='

do $$
declare v_sub uuid;
begin
  call pg_temp.become('dddddddd-0000-0000-0000-000000000001');

  insert into public.kyc_submissions (subject_id, requested_tier)
  values ('dddddddd-0000-0000-0000-000000000001', 'tier_2')
  returning id into v_sub;

  call pg_temp.denied(
    format($q$select public.submit_kyc(%L)$q$, v_sub),
    'a tier 2 application with no documents is refused');

  insert into public.kyc_documents (submission_id, document_type, storage_path)
  values (v_sub, 'gov_id_front', 'dddddddd-0000-0000-0000-000000000001/' || v_sub || '/front');

  call pg_temp.denied(
    format($q$select public.submit_kyc(%L)$q$, v_sub),
    'still refused with only one of the three documents');

  insert into public.kyc_documents (submission_id, document_type, storage_path) values
    (v_sub, 'gov_id_back', 'dddddddd-0000-0000-0000-000000000001/' || v_sub || '/back'),
    (v_sub, 'selfie',      'dddddddd-0000-0000-0000-000000000001/' || v_sub || '/selfie');

  perform public.submit_kyc(v_sub);
  call pg_temp.ok(true, 'accepted once every required document is attached');
end $$;
reset role;

\echo ''
\echo '=== only compliance reviews, and never their own application ==='

do $$
declare v_sub uuid; v_tier public.kyc_tier;
begin
  select id into v_sub from public.kyc_submissions where status = 'submitted' limit 1;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000004');
  call pg_temp.denied(
    format($q$select public.review_kyc(%L, true)$q$, v_sub),
    'the trading desk cannot approve an application');
  reset role;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$select public.review_kyc(%L, true)$q$, v_sub),
    'the applicant cannot approve themselves');
  reset role;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000003');
  call pg_temp.denied(
    format($q$select public.review_kyc(%L, false, '')$q$, v_sub),
    'a rejection with no reason is refused');

  perform public.review_kyc(v_sub, true, 'ID matches the selfie.');
  reset role;

  select kyc_tier into v_tier from public.profiles
   where id = 'dddddddd-0000-0000-0000-000000000001';
  call pg_temp.ok(v_tier = 'tier_2', 'approval raised the tier (got ' || v_tier || ')');
end $$;
reset role;

\echo ''
\echo '=== the decision is attributable and timestamped ==='

do $$
declare v_by uuid; v_at timestamptz;
begin
  select reviewed_by, reviewed_at into v_by, v_at
  from public.kyc_submissions where status = 'approved' limit 1;
  call pg_temp.ok(v_by = 'dddddddd-0000-0000-0000-000000000003',
                  'the decision names the reviewer');
  call pg_temp.ok(v_at is not null, 'and records when it was made');
end $$;

\echo ''
\echo '=== identity documents are visible only to their subject and compliance ==='

do $$
declare n int;
begin
  call pg_temp.become('dddddddd-0000-0000-0000-000000000001');
  select count(*) into n from public.kyc_documents;
  call pg_temp.ok(n = 3, 'the subject sees their own documents (got ' || n || ')');
  reset role;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000004');
  select count(*) into n from public.kyc_documents;
  call pg_temp.ok(n = 0, 'the trading desk sees no identity documents (got ' || n || ')');
  reset role;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000005');
  select count(*) into n from public.kyc_documents;
  call pg_temp.ok(n = 0, 'a buyer sees no identity documents (got ' || n || ')');
  reset role;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000003');
  select count(*) into n from public.kyc_documents;
  call pg_temp.ok(n = 3, 'compliance sees them (got ' || n || ')');
end $$;
reset role;

\echo ''
\echo '=== a document cannot be added to an application already under review ==='

do $$
declare v_sub uuid;
begin
  select id into v_sub from public.kyc_submissions where status = 'approved' limit 1;
  call pg_temp.become('dddddddd-0000-0000-0000-000000000001');
  call pg_temp.denied(
    format($q$insert into public.kyc_documents (submission_id, document_type, storage_path)
              values (%L, 'portrait', 'x/y/z')$q$, v_sub),
    'documents cannot be added after submission');
end $$;
reset role;

\echo ''
\echo '=== the audit trail records that a document existed, never its contents ==='

do $$
declare n int; v_ctx jsonb; v_after jsonb;
begin
  select count(*) into n from public.audit_log where entity_table = 'kyc_documents';
  call pg_temp.ok(n >= 3, 'document events were audit-logged (' || n || ')');

  select context, after_state into v_ctx, v_after
  from public.audit_log where entity_table = 'kyc_documents' limit 1;

  call pg_temp.ok(v_after is null,
                  'the audit row holds no copy of the document record');
  call pg_temp.ok(v_ctx ? 'document_type',
                  'but does record which kind of document it was');
end $$;

\echo ''
\echo '=== storage: identity documents are private to their owner ==='

do $$
declare n int; v_pub boolean;
begin
  select public into v_pub from storage.buckets where id = 'kyc-documents';
  call pg_temp.ok(v_pub = false, 'the bucket is private');

  insert into storage.objects (bucket_id, name, owner) values
    ('kyc-documents', 'dddddddd-0000-0000-0000-000000000001/sub/front',
     'dddddddd-0000-0000-0000-000000000001'),
    ('kyc-documents', 'dddddddd-0000-0000-0000-000000000005/sub/front',
     'dddddddd-0000-0000-0000-000000000005');

  call pg_temp.become('dddddddd-0000-0000-0000-000000000001');
  select count(*) into n from storage.objects;
  call pg_temp.ok(n = 1, 'a person sees only their own uploaded files (got ' || n || ')');

  call pg_temp.denied(
    $q$insert into storage.objects (bucket_id, name, owner)
       values ('kyc-documents','dddddddd-0000-0000-0000-000000000005/sub/forged',
               'dddddddd-0000-0000-0000-000000000001')$q$,
    'and cannot upload into somebody else''s folder');
  reset role;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000004');
  select count(*) into n from storage.objects;
  call pg_temp.ok(n = 0, 'the trading desk sees no identity files (got ' || n || ')');
  reset role;

  call pg_temp.become('dddddddd-0000-0000-0000-000000000003');
  select count(*) into n from storage.objects;
  call pg_temp.ok(n = 2, 'compliance sees them (got ' || n || ')');

  -- A reviewer deleting the evidence they decided on would leave an unauditable
  -- decision; §9 retention is a scheduled destruction, not an ad-hoc one.
  delete from storage.objects
   where name like 'dddddddd-0000-0000-0000-000000000001%';
  select count(*) into n from storage.objects;
  call pg_temp.ok(n = 2, 'and compliance cannot delete them (still ' || n || ')');
end $$;
reset role;

rollback;

\echo ''
\echo 'All KYC tests passed.'
