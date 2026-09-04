-- M2 slice 4 / FR-4: cooperatives.
--
-- A cooperative lets members reach a volume none of them could alone. It is a
-- selling arrangement, not a shared identity: FR-4 requires that "a farmer's
-- individual identity and Vault balance stay separate from the group's", so a
-- member's contribution is recorded against that member throughout and never
-- merged into a single pooled figure.

create type public.membership_status as enum (
  'invited',   -- asked, not yet answered
  'active',
  'declined',  -- the farmer said no
  'left',      -- the farmer withdrew
  'removed'    -- the officer removed them
);

create table public.cooperatives (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,

  -- FR-4: a group has a named officer. Not nullable, because a group nobody is
  -- answerable for is a group nobody can be asked about.
  officer_id         uuid not null references public.profiles (id) on delete restrict,

  region_code        text not null references public.regions (code),
  barangay           text not null,
  city_municipality  text not null,
  province           text not null,

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint cooperatives_name_not_blank check (length(btrim(name)) > 0)
);

create index cooperatives_officer_idx on public.cooperatives (officer_id);

create table public.cooperative_memberships (
  id              uuid primary key default gen_random_uuid(),
  cooperative_id  uuid not null references public.cooperatives (id) on delete cascade,
  farmer_id       uuid not null references public.profiles (id) on delete cascade,

  status          public.membership_status not null default 'invited',

  invited_by      uuid references public.profiles (id),
  invited_at      timestamptz not null default now(),
  responded_at    timestamptz,
  ended_at        timestamptz,

  -- FR-4: farmers join by invitation and must accept. An answer has a time.
  constraint memberships_answer_recorded
    check (status = 'invited' or responded_at is not null),
  constraint memberships_ending_recorded
    check (status not in ('left', 'removed') or ended_at is not null)
);

-- One live relationship per person per group. A farmer who left and is invited
-- again gets a new row, so the history of joining and leaving survives.
create unique index memberships_one_live_per_farmer
  on public.cooperative_memberships (cooperative_id, farmer_id)
  where status in ('invited', 'active');

create index memberships_farmer_idx on public.cooperative_memberships (farmer_id);
create index memberships_cooperative_idx on public.cooperative_memberships (cooperative_id);

-- The officer is a member from the start: they sell through the group like anyone
-- else, and their own contributions must be attributable in the same way.
create or replace function public.add_officer_as_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.cooperative_memberships
    (cooperative_id, farmer_id, status, invited_by, responded_at)
  values (new.id, new.officer_id, 'active', new.officer_id, now())
  on conflict do nothing;
  return new;
end;
$$;

create trigger cooperatives_add_officer
  after insert on public.cooperatives
  for each row execute function public.add_officer_as_member();

create trigger cooperatives_touch_updated_at
  before update on public.cooperatives
  for each row execute function public.touch_updated_at();

create trigger cooperatives_audit
  after insert or update or delete on public.cooperatives
  for each row execute function public.audit_row_change();

create trigger memberships_audit
  after insert or update or delete on public.cooperative_memberships
  for each row execute function public.audit_row_change();

-- ---------------------------------------------------------------------------
-- Membership helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_cooperative_member(p_cooperative uuid, p_farmer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.cooperative_memberships m
    where m.cooperative_id = p_cooperative
      and m.farmer_id = p_farmer
      and m.status = 'active'
  );
$$;

create or replace function public.is_cooperative_officer(p_cooperative uuid, p_person uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.cooperatives c
    where c.id = p_cooperative and c.officer_id = p_person
  );
$$;

-- FR-4: a farmer joins by accepting, and may leave. Both are the farmer's own
-- action — an officer cannot accept on somebody's behalf.
create or replace function public.respond_to_invitation(
  p_membership_id uuid,
  p_accept        boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_membership record;
begin
  select * into v_membership from public.cooperative_memberships
   where id = p_membership_id for update;

  if not found or v_membership.farmer_id <> auth.uid() then
    raise exception 'invitation not found' using errcode = 'insufficient_privilege';
  end if;

  if v_membership.status <> 'invited' then
    raise exception 'this invitation has already been answered'
      using errcode = 'check_violation';
  end if;

  update public.cooperative_memberships
     set status = case when p_accept then 'active' else 'declined' end::public.membership_status,
         responded_at = now()
   where id = p_membership_id;
end;
$$;

create or replace function public.leave_cooperative(p_membership_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_membership record;
  v_officer    uuid;
begin
  select * into v_membership from public.cooperative_memberships
   where id = p_membership_id for update;

  if not found or v_membership.farmer_id <> auth.uid() then
    raise exception 'membership not found' using errcode = 'insufficient_privilege';
  end if;

  if v_membership.status <> 'active' then
    raise exception 'you are not an active member of this group'
      using errcode = 'check_violation';
  end if;

  select officer_id into v_officer from public.cooperatives
   where id = v_membership.cooperative_id;

  -- The officer is the person the group is answerable through, so they cannot
  -- simply walk away and leave it unattended. Handing the role over first is a
  -- separate action, and a deliberate one.
  if v_officer = v_membership.farmer_id then
    raise exception 'the officer cannot leave the group; hand the role over first'
      using errcode = 'check_violation';
  end if;

  update public.cooperative_memberships
     set status = 'left', ended_at = now()
   where id = p_membership_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.cooperatives enable row level security;
alter table public.cooperative_memberships enable row level security;

create policy "members read their cooperative"
  on public.cooperatives for select to authenticated
  using (
    officer_id = (select auth.uid())
    or public.is_cooperative_member(id, (select auth.uid()))
  );

-- Buyers see the group behind a group listing: knowing who you are buying from
-- is the point of consolidated selling.
create policy "buyers read cooperatives"
  on public.cooperatives for select to authenticated
  using (public.has_any_role('buyer', 'trading_desk', 'bagsakan_operator'));

create policy "compliance and admin read cooperatives"
  on public.cooperatives for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

-- Whoever registers a group is its first officer. Registering one in somebody
-- else's name would make them answerable for something they never agreed to.
create policy "register own cooperative"
  on public.cooperatives for insert to authenticated
  with check (officer_id = (select auth.uid()));

create policy "officer updates own cooperative"
  on public.cooperatives for update to authenticated
  using (officer_id = (select auth.uid()))
  with check (officer_id = (select auth.uid()));

create policy "read own memberships"
  on public.cooperative_memberships for select to authenticated
  using ((select auth.uid()) = farmer_id);

create policy "officer reads memberships"
  on public.cooperative_memberships for select to authenticated
  using (public.is_cooperative_officer(cooperative_id, (select auth.uid())));

create policy "compliance and admin read memberships"
  on public.cooperative_memberships for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

-- Only the officer invites, and only as an invitation: 'active' is reachable
-- solely through respond_to_invitation(), so nobody is enrolled without saying yes.
create policy "officer invites"
  on public.cooperative_memberships for insert to authenticated
  with check (
    public.is_cooperative_officer(cooperative_id, (select auth.uid()))
    and status = 'invited'
    and invited_by = (select auth.uid())
  );

-- The officer may remove a member, but cannot accept on their behalf: an update
-- to 'active' is refused here and only the farmer's own function can make it.
create policy "officer removes a member"
  on public.cooperative_memberships for update to authenticated
  using (
    public.is_cooperative_officer(cooperative_id, (select auth.uid()))
    and farmer_id <> (select auth.uid())
  )
  with check (
    public.is_cooperative_officer(cooperative_id, (select auth.uid()))
    and status = 'removed'
  );
