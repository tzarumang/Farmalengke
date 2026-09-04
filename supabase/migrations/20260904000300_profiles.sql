-- M1 Foundation: user profiles (FR-1), and RLS across the foundation tables.

create table public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,

  -- FR-1: mobile number is the identity. E.164, so the same number cannot be
  -- registered twice under different formatting.
  mobile_number      text not null unique,

  display_name       text,

  -- PRD section 8: Filipino and English at launch, three more without code change.
  preferred_language text not null default 'fil',

  -- PRD section 9 data minimisation: barangay granularity by default. A GPS point
  -- is farm-level, needs explicit consent, and arrives with farm records in M2.
  barangay           text,
  city_municipality  text,
  province           text,

  -- Privileged. A user may not set these on themselves -- see the trigger below.
  kyc_tier           public.kyc_tier    not null default 'tier_0',
  status             public.account_status not null default 'pending',

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint profiles_mobile_e164
    check (mobile_number ~ '^\+[1-9][0-9]{7,14}$'),
  constraint profiles_language_supported
    check (preferred_language in ('fil', 'en', 'ceb', 'ilo', 'hil'))
);

create index profiles_status_idx on public.profiles (status);

comment on column public.profiles.kyc_tier is
  'Privileged: set by compliance review (FR-2), never by the user.';
comment on column public.profiles.barangay is
  'Coarse location by default. GPS is per-farm and consent-gated (PRD section 9).';

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Privileged columns
-- ---------------------------------------------------------------------------
--
-- RLS is row-level, not column-level, so "a user may edit their profile but not
-- their own KYC tier" cannot be expressed as a policy. A trigger closes that gap.
create or replace function public.guard_profile_privileged_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.kyc_tier is distinct from old.kyc_tier
     and not public.has_any_role('compliance', 'admin') then
    raise exception 'kyc_tier is set by compliance review, not by the account holder'
      using errcode = 'insufficient_privilege';
  end if;

  if new.status is distinct from old.status
     and not public.has_any_role('compliance', 'admin') then
    raise exception 'account status is set by compliance or an administrator'
      using errcode = 'insufficient_privilege';
  end if;

  -- The profile is keyed to the auth user; re-pointing it would sever that link.
  if new.id is distinct from old.id then
    raise exception 'profile id is immutable';
  end if;

  return new;
end;
$$;

create trigger profiles_guard_privileged
  before update on public.profiles
  for each row execute function public.guard_profile_privileged_columns();

-- Every profile change is recorded (FR-28).
create trigger profiles_audit
  after insert or update or delete on public.profiles
  for each row execute function public.audit_row_change();

-- ---------------------------------------------------------------------------
-- Row-level security: profiles
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;

create policy "read own profile"
  on public.profiles for select
  to authenticated
  using ( (select auth.uid()) = id );

-- Compliance reviews KYC; admin administers. Neither is a general read-everything
-- grant for staff -- the trading desk has no business reading farmer identities.
create policy "compliance and admin read profiles"
  on public.profiles for select
  to authenticated
  using ( public.has_any_role('compliance', 'admin') );

create policy "create own profile"
  on public.profiles for insert
  to authenticated
  with check ( (select auth.uid()) = id );

create policy "update own profile"
  on public.profiles for update
  to authenticated
  using ( (select auth.uid()) = id )
  with check ( (select auth.uid()) = id );

create policy "compliance and admin update profiles"
  on public.profiles for update
  to authenticated
  using ( public.has_any_role('compliance', 'admin') )
  with check ( public.has_any_role('compliance', 'admin') );

-- No DELETE policy. Financial record retention (PRD section 9) means a profile is
-- closed by status, not removed. Erasure requests are handled deliberately, not by
-- an ordinary delete.

-- ---------------------------------------------------------------------------
-- Row-level security: user_roles
-- ---------------------------------------------------------------------------

alter table public.user_roles enable row level security;

create policy "read own role grants"
  on public.user_roles for select
  to authenticated
  using ( (select auth.uid()) = user_id );

create policy "compliance and admin read role grants"
  on public.user_roles for select
  to authenticated
  using ( public.has_any_role('compliance', 'admin') );

-- Only an administrator grants roles, and never to themselves: self-granting is how
-- a compromised staff account escalates to everything else.
create policy "admin grants roles"
  on public.user_roles for insert
  to authenticated
  with check (
    public.has_role('admin')
    and user_id <> (select auth.uid())
    and granted_by = (select auth.uid())
  );

create policy "admin revokes roles"
  on public.user_roles for update
  to authenticated
  using ( public.has_role('admin') and user_id <> (select auth.uid()) )
  with check ( public.has_role('admin') and user_id <> (select auth.uid()) );

-- No DELETE policy: grants are revoked (revoked_at), never erased.

create trigger user_roles_audit
  after insert or update or delete on public.user_roles
  for each row execute function public.audit_row_change();
