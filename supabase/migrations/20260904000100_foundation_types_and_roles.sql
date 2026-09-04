-- M1 Foundation: enum types, role assignment, and the JWT role hook.
--
-- Authorization reads roles from the JWT's app_metadata, never from user_metadata,
-- because user_metadata is editable by the user it describes. The custom access token
-- hook below is what puts the roles there.

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

-- The nine personas in PRD section 4.
create type public.user_role as enum (
  'farmer',
  'coop_officer',
  'bagsakan_operator',
  'buyer',
  'logistics_provider',
  'trading_desk',
  'treasury',
  'compliance',
  'admin'
);

-- Tiered KYC per FR-2. Tier 0 cannot transact; thresholds for 1 and 2 come from the
-- legal opinion in PRD Q6 and are configuration, not schema.
create type public.kyc_tier as enum ('tier_0', 'tier_1', 'tier_2');

create type public.account_status as enum ('pending', 'active', 'suspended', 'closed');

create type public.audit_operation as enum ('insert', 'update', 'delete');

-- ---------------------------------------------------------------------------
-- Role assignment
-- ---------------------------------------------------------------------------

create table public.user_roles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        public.user_role not null,
  granted_by  uuid references auth.users (id),
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz,
  revoked_by  uuid references auth.users (id),

  -- A revocation must record who performed it.
  constraint user_roles_revocation_attributed
    check ((revoked_at is null) = (revoked_by is null))
);

-- One active grant per (user, role). Revoked grants are kept for the audit trail,
-- so uniqueness applies only while the grant is live.
create unique index user_roles_active_unique
  on public.user_roles (user_id, role)
  where revoked_at is null;

-- Indexed because RLS policies filter on it (see security-by-design guidance).
create index user_roles_user_id_idx on public.user_roles (user_id);

comment on table public.user_roles is
  'Role grants. Revoked rows are retained rather than deleted so the audit trail stays intact.';

-- ---------------------------------------------------------------------------
-- Role lookup helpers
-- ---------------------------------------------------------------------------

-- Reads roles from the verified JWT. STABLE so Postgres caches it per statement.
create or replace function public.current_roles()
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(
    array(
      select jsonb_array_elements_text(
        coalesce(auth.jwt() -> 'app_metadata' -> 'roles', '[]'::jsonb)
      )
    ),
    array[]::text[]
  );
$$;

create or replace function public.has_role(target public.user_role)
returns boolean
language sql
stable
set search_path = ''
as $$
  select target::text = any (public.current_roles());
$$;

-- Convenience for the several policies that admit any staff role. Deliberately does
-- NOT include 'admin' as a synonym for everything -- see has_role checks at each use.
create or replace function public.has_any_role(variadic targets public.user_role[])
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from unnest(targets) as t(role)
    where t.role::text = any (public.current_roles())
  );
$$;

-- ---------------------------------------------------------------------------
-- Custom access token hook: puts active roles into app_metadata at token issue
-- ---------------------------------------------------------------------------
--
-- Supabase calls this when minting an access token. Returning the event with roles
-- added to app_metadata is what makes has_role() work, and it means a revoked role
-- disappears at the next token refresh without any application involvement.
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  claims     jsonb;
  user_roles jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(ur.role::text)), '[]'::jsonb)
    into user_roles
  from public.user_roles ur
  where ur.user_id = (event ->> 'user_id')::uuid
    and ur.revoked_at is null;

  claims := coalesce(event -> 'claims', '{}'::jsonb);

  claims := jsonb_set(
    claims,
    '{app_metadata}',
    coalesce(claims -> 'app_metadata', '{}'::jsonb) || jsonb_build_object('roles', user_roles)
  );

  return jsonb_set(event, '{claims}', claims);
end;
$$;

comment on function public.custom_access_token_hook(jsonb) is
  'Auth hook: injects active role grants into the access token app_metadata claim.';
