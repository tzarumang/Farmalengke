-- Row-level security tests.
--
-- Each case impersonates a user by setting the role to `authenticated` and supplying
-- a JWT claims payload, exactly as PostgREST does. Anything that should be refused is
-- asserted to actually raise or return zero rows -- a policy nobody has attacked is
-- only a policy you hope works.

\set ON_ERROR_STOP on
\timing off
\pset pager off

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

create temporary table t_ids (label text primary key, id uuid);

insert into auth.users (id, phone) values
  ('11111111-1111-1111-1111-111111111111', '+639170000001'),
  ('22222222-2222-2222-2222-222222222222', '+639170000002'),
  ('33333333-3333-3333-3333-333333333333', '+639170000003'),
  ('44444444-4444-4444-4444-444444444444', '+639170000004'),
  ('55555555-5555-5555-5555-555555555555', '+639170000005');

insert into t_ids values
  ('farmer_a',   '11111111-1111-1111-1111-111111111111'),
  ('farmer_b',   '22222222-2222-2222-2222-222222222222'),
  ('compliance', '33333333-3333-3333-3333-333333333333'),
  ('admin',      '44444444-4444-4444-4444-444444444444'),
  ('trading',    '55555555-5555-5555-5555-555555555555');

-- Seed roles directly (as owner) so the hook has something to read.
insert into public.user_roles (user_id, role, granted_by) values
  ('11111111-1111-1111-1111-111111111111', 'farmer',       null),
  ('22222222-2222-2222-2222-222222222222', 'farmer',       null),
  ('33333333-3333-3333-3333-333333333333', 'compliance',   null),
  ('44444444-4444-4444-4444-444444444444', 'admin',        null),
  ('55555555-5555-5555-5555-555555555555', 'trading_desk', null);

-- Helper: build a claims payload the way the access token hook would.
create or replace function pg_temp.claims_for(p_user uuid)
returns text
language sql
as $$
  select jsonb_build_object(
    'sub', p_user::text,
    'role', 'authenticated',
    'app_metadata', jsonb_build_object(
      'roles', coalesce(
        (select jsonb_agg(to_jsonb(ur.role::text))
           from public.user_roles ur
          where ur.user_id = p_user and ur.revoked_at is null),
        '[]'::jsonb)
    )
  )::text;
$$;

create or replace procedure pg_temp.become(p_user uuid)
language plpgsql
as $$
declare
  v_claims text;
begin
  -- Build the claims BEFORE dropping to `authenticated`. Computing them afterwards
  -- would run the lookup under RLS, which returns no roles and silently produces a
  -- token weaker than the one Supabase would actually mint.
  v_claims := pg_temp.claims_for(p_user);
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims = %L', v_claims);
end;
$$;

create or replace procedure pg_temp.become_owner()
language plpgsql
as $$
begin
  reset role;
  execute 'set local request.jwt.claims = ''''';
end;
$$;

create or replace procedure pg_temp.ok(p_condition boolean, p_label text)
language plpgsql
as $$
begin
  if p_condition then
    raise notice '  PASS  %', p_label;
  else
    raise exception 'FAIL  %', p_label;
  end if;
end;
$$;

-- Asserts that a statement is refused. Passing silently would be the bug.
create or replace procedure pg_temp.denied(p_sql text, p_label text)
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception when others then
    raise notice '  PASS  % (refused: %)', p_label, replace(sqlerrm, E'\n', ' ');
    return;
  end;
  raise exception 'FAIL  % -- the statement was ALLOWED and should not have been', p_label;
end;
$$;

-- ---------------------------------------------------------------------------

\echo ''
\echo '=== The access token hook reflects granted roles ==='

do $$
declare c jsonb;
begin
  c := public.custom_access_token_hook(
         jsonb_build_object(
           'user_id', '33333333-3333-3333-3333-333333333333',
           'claims', jsonb_build_object('sub', '33333333-3333-3333-3333-333333333333')));
  call pg_temp.ok(c -> 'claims' -> 'app_metadata' -> 'roles' ? 'compliance',
                  'hook puts the compliance role into app_metadata');
  call pg_temp.ok(not (c -> 'claims' -> 'app_metadata' -> 'roles' ? 'admin'),
                  'hook does not invent roles the user was never granted');
end $$;

\echo ''
\echo '=== profiles: a farmer sees only their own row ==='

-- Seed profiles as owner.
insert into public.profiles (id, mobile_number, display_name) values
  ('11111111-1111-1111-1111-111111111111', '+639170000001', 'Farmer A'),
  ('22222222-2222-2222-2222-222222222222', '+639170000002', 'Farmer B'),
  ('33333333-3333-3333-3333-333333333333', '+639170000003', 'Compliance'),
  ('44444444-4444-4444-4444-444444444444', '+639170000004', 'Admin'),
  ('55555555-5555-5555-5555-555555555555', '+639170000005', 'Trading Desk');

do $$
declare n int;
begin
  call pg_temp.become('11111111-1111-1111-1111-111111111111');
  select count(*) into n from public.profiles;
  call pg_temp.ok(n = 1, 'farmer A sees exactly 1 profile, not 5 (got ' || n || ')');

  select count(*) into n from public.profiles where id = '22222222-2222-2222-2222-222222222222';
  call pg_temp.ok(n = 0, 'farmer A cannot read farmer B''s profile');
end $$;
reset role;

\echo ''
\echo '=== profiles: staff visibility is scoped by role, not granted wholesale ==='

do $$
declare n int;
begin
  call pg_temp.become('33333333-3333-3333-3333-333333333333');
  select count(*) into n from public.profiles;
  call pg_temp.ok(n = 5, 'compliance reads all profiles (got ' || n || ')');
  reset role;

  call pg_temp.become('55555555-5555-5555-5555-555555555555');
  select count(*) into n from public.profiles;
  call pg_temp.ok(n = 1, 'the trading desk reads only its own profile, not farmers'' (got ' || n || ')');
end $$;
reset role;

\echo ''
\echo '=== profiles: a user cannot raise their own KYC tier or status ==='

do $$
begin
  call pg_temp.become('11111111-1111-1111-1111-111111111111');
  call pg_temp.denied(
    $q$update public.profiles set kyc_tier = 'tier_2' where id = '11111111-1111-1111-1111-111111111111'$q$,
    'farmer cannot self-promote kyc_tier');
  call pg_temp.denied(
    $q$update public.profiles set status = 'active' where id = '11111111-1111-1111-1111-111111111111'$q$,
    'farmer cannot self-activate their account');
end $$;
reset role;

do $$
declare v public.kyc_tier;
begin
  call pg_temp.become('33333333-3333-3333-3333-333333333333');
  update public.profiles set kyc_tier = 'tier_1'
   where id = '11111111-1111-1111-1111-111111111111';
  reset role;
  select kyc_tier into v from public.profiles where id = '11111111-1111-1111-1111-111111111111';
  call pg_temp.ok(v = 'tier_1', 'compliance CAN set kyc_tier');
end $$;
reset role;

\echo ''
\echo '=== profiles: a farmer can edit their own non-privileged fields ==='

do $$
declare v text;
begin
  call pg_temp.become('11111111-1111-1111-1111-111111111111');
  update public.profiles set display_name = 'Aling Maria', barangay = 'San Isidro'
   where id = '11111111-1111-1111-1111-111111111111';
  reset role;
  select display_name into v from public.profiles where id = '11111111-1111-1111-1111-111111111111';
  call pg_temp.ok(v = 'Aling Maria', 'farmer can update their own display name');
end $$;
reset role;

\echo ''
\echo '=== profiles: one farmer cannot write another farmer''s row ==='

do $$
declare n int;
begin
  call pg_temp.become('11111111-1111-1111-1111-111111111111');
  update public.profiles set display_name = 'hijacked'
   where id = '22222222-2222-2222-2222-222222222222';
  get diagnostics n = row_count;
  call pg_temp.ok(n = 0, 'farmer A''s update of farmer B''s row affects 0 rows');

  call pg_temp.denied(
    $q$insert into public.profiles (id, mobile_number) values ('22222222-2222-2222-2222-222222222222','+639179999999')$q$,
    'farmer A cannot insert a profile owned by someone else');
end $$;
reset role;

\echo ''
\echo '=== user_roles: only an admin grants, and never to themselves ==='

do $$
begin
  call pg_temp.become('11111111-1111-1111-1111-111111111111');
  call pg_temp.denied(
    $q$insert into public.user_roles (user_id, role, granted_by)
       values ('11111111-1111-1111-1111-111111111111','admin','11111111-1111-1111-1111-111111111111')$q$,
    'farmer cannot grant themselves admin');
  reset role;

  call pg_temp.become('44444444-4444-4444-4444-444444444444');
  call pg_temp.denied(
    $q$insert into public.user_roles (user_id, role, granted_by)
       values ('44444444-4444-4444-4444-444444444444','treasury','44444444-4444-4444-4444-444444444444')$q$,
    'admin cannot grant a role to themselves (separation of duties)');

  insert into public.user_roles (user_id, role, granted_by)
  values ('22222222-2222-2222-2222-222222222222','buyer','44444444-4444-4444-4444-444444444444');
  call pg_temp.ok(true, 'admin CAN grant a role to another user');
end $$;
reset role;

\echo ''
\echo '=== audit_log: append-only, and unreadable to those it does not concern ==='

do $$
declare n int;
begin
  -- Profile changes above should already have been recorded by the trigger.
  select count(*) into n from public.audit_log where entity_table = 'profiles';
  call pg_temp.ok(n > 0, 'profile changes were audit-logged automatically (' || n || ' entries)');

  select count(*) into n from public.audit_log where entity_table = 'user_roles';
  call pg_temp.ok(n > 0, 'role grants were audit-logged automatically (' || n || ' entries)');
end $$;

do $$
declare n int;
begin
  call pg_temp.become('11111111-1111-1111-1111-111111111111');
  select count(*) into n from public.audit_log;
  call pg_temp.ok(n = 0, 'a farmer cannot read the audit log (got ' || n || ')');
  reset role;

  call pg_temp.become('33333333-3333-3333-3333-333333333333');
  select count(*) into n from public.audit_log;
  call pg_temp.ok(n > 0, 'compliance can read the audit log (got ' || n || ')');
end $$;
reset role;

do $$
begin
  call pg_temp.become('44444444-4444-4444-4444-444444444444');
  call pg_temp.denied($q$update public.audit_log set action = 'tampered'$q$,
                      'an ADMIN cannot update the audit log');
  call pg_temp.denied($q$delete from public.audit_log$q$,
                      'an ADMIN cannot delete from the audit log');
end $$;
reset role;

-- The strongest form of the FR-28 claim: even the table owner, bypassing RLS
-- entirely, is stopped by the trigger.
do $$
begin
  call pg_temp.denied($q$update public.audit_log set action = 'tampered'$q$,
                      'the table OWNER cannot update the audit log (trigger holds)');
  call pg_temp.denied($q$delete from public.audit_log$q$,
                      'the table OWNER cannot delete from the audit log (trigger holds)');
  call pg_temp.denied($q$truncate public.audit_log$q$,
                      'the table OWNER cannot truncate the audit log');
end $$;

\echo ''
\echo '=== audit_log: the actor is taken from the session, not from the caller ==='

do $$
declare v uuid;
begin
  call pg_temp.become('11111111-1111-1111-1111-111111111111');
  perform public.record_audit_event('test.event', 'profiles', 'x');
  reset role;
  select actor_id into v from public.audit_log
   where action = 'test.event' order by id desc limit 1;
  call pg_temp.ok(v = '11111111-1111-1111-1111-111111111111',
                  'the recorded actor is the session user');
end $$;
reset role;

\echo ''
\echo '=== RLS is enabled on every table in the public schema ==='

do $$
declare missing text;
begin
  select string_agg(c.relname, ', ')
    into missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

  call pg_temp.ok(missing is null,
                  'no public table is missing RLS' ||
                  coalesce(' -- MISSING: ' || missing, ''));
end $$;

rollback;

\echo ''
\echo 'All RLS tests passed.'
