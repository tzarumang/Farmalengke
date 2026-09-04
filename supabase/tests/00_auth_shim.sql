-- TEST SUPPORT ONLY -- never applied to a real database.
--
-- Reproduces the parts of Supabase's auth schema that the migrations depend on, so
-- the policies can be executed and asserted against a plain PostgreSQL server. In a
-- real Supabase instance (hosted or self-hosted) all of this already exists and this
-- file is not used.

create schema if not exists auth;

create table if not exists auth.users (
  id    uuid primary key default gen_random_uuid(),
  phone text unique
);

-- Supabase exposes the verified JWT to policies through these two functions. The
-- test harness sets request.jwt.claims to impersonate a user.
create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(auth.jwt() ->> 'sub', '')::uuid;
$$;

-- Supabase's built-in roles.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth   to anon, authenticated, service_role;
grant select on auth.users   to authenticated, service_role;

-- Supabase grants table privileges to these roles by default; RLS is what actually
-- constrains them. Reproducing that here means the tests exercise the real posture:
-- a broad grant, narrowed by policy.
alter default privileges in schema public
  grant select, insert, update, delete on tables to anon, authenticated;
