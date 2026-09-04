-- M2 slice 4 / FR-4: consolidated selling.
--
-- A group listing is offered by the officer on the cooperative's behalf, and
-- records what each member put into it. FR-4 requires that identities stay
-- separate, so the contributions are the substance of the listing rather than a
-- decorative breakdown of one pooled number.

alter table public.produce_listings
  add column cooperative_id uuid references public.cooperatives (id) on delete restrict;

create index produce_listings_cooperative_idx
  on public.produce_listings (cooperative_id)
  where cooperative_id is not null;

comment on column public.produce_listings.cooperative_id is
  'Set when the listing is sold on a group''s behalf. farmer_id then holds the '
  'officer, who acts — not a single owner of the produce.';

create table public.listing_contributions (
  id           uuid primary key default gen_random_uuid(),
  listing_id   uuid not null references public.produce_listings (id) on delete cascade,
  farmer_id    uuid not null references public.profiles (id) on delete restrict,

  quantity_kg  numeric(12, 3) not null,

  created_at   timestamptz not null default now(),

  constraint listing_contributions_positive check (quantity_kg > 0)
);

create unique index listing_contributions_one_per_farmer
  on public.listing_contributions (listing_id, farmer_id);

create index listing_contributions_listing_idx on public.listing_contributions (listing_id);
create index listing_contributions_farmer_idx on public.listing_contributions (farmer_id);

comment on table public.listing_contributions is
  'Who put what into a group listing. This is what keeps a member''s share '
  'attributable to them rather than merged into the group (FR-4).';

-- ---------------------------------------------------------------------------
-- A group listing must be coherent
-- ---------------------------------------------------------------------------

create or replace function public.guard_group_listing()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_contributed numeric;
begin
  if new.cooperative_id is null then
    return new;
  end if;

  -- The officer is the only person who can offer on the group's behalf, and
  -- farmer_id records who acted.
  if not public.is_cooperative_officer(new.cooperative_id, new.farmer_id) then
    raise exception 'only the officer may list on a group''s behalf'
      using errcode = 'insufficient_privilege';
  end if;

  -- Offering it means the contributions must add up. A draft may be incomplete
  -- while the officer is still collecting what members are bringing.
  if new.status = 'active' then
    select coalesce(sum(c.quantity_kg), 0) into v_contributed
    from public.listing_contributions c
    where c.listing_id = new.id;

    if v_contributed <> new.quantity_kg then
      raise exception
        'contributions total % kg but the listing is % kg; they must match before it is offered',
        v_contributed, new.quantity_kg
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$$;

create trigger produce_listings_guard_group
  before insert or update on public.produce_listings
  for each row execute function public.guard_group_listing();

-- Only active members may be recorded as contributors: a group cannot sell on
-- behalf of somebody who never joined, or who has left.
create or replace function public.guard_contribution_membership()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_cooperative uuid;
begin
  select cooperative_id into v_cooperative
  from public.produce_listings where id = new.listing_id;

  if v_cooperative is null then
    raise exception 'contributions belong to group listings only'
      using errcode = 'check_violation';
  end if;

  if not public.is_cooperative_member(v_cooperative, new.farmer_id) then
    raise exception 'that farmer is not an active member of this group'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

create trigger listing_contributions_guard_membership
  before insert or update on public.listing_contributions
  for each row execute function public.guard_contribution_membership();

create trigger listing_contributions_audit
  after insert or update or delete on public.listing_contributions
  for each row execute function public.audit_row_change();

-- ---------------------------------------------------------------------------
-- Verification ceilings on a group sale
-- ---------------------------------------------------------------------------
--
-- This is the part that matters. If confirming a group sale only checked the
-- officer's tier, a cooperative would be a way round verification entirely: an
-- unverified farmer could sell any volume by routing it through a group whose
-- officer happens to be verified.
--
-- FR-4 says a member's identity stays separate from the group's, which settles
-- it — each member is transacting on their own account, so each member's share
-- is checked against their own ceiling. A group can only sell as much as its
-- members are individually verified to sell.

create or replace function public.group_ceiling_breach(
  p_listing_id uuid,
  p_line_total numeric
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_listing_kg numeric;
  v_row        record;
  v_share      numeric;
  v_breach     text;
begin
  select quantity_kg into v_listing_kg
  from public.produce_listings where id = p_listing_id;

  if v_listing_kg is null or v_listing_kg = 0 then
    return null;
  end if;

  for v_row in
    select c.farmer_id, c.quantity_kg, p.display_name
    from public.listing_contributions c
    join public.profiles p on p.id = c.farmer_id
    where c.listing_id = p_listing_id
  loop
    v_share := round(p_line_total * (v_row.quantity_kg / v_listing_kg), 2);
    v_breach := public.kyc_ceiling_breach(v_row.farmer_id, v_share);

    if v_breach is not null then
      return format('%s cannot take their share of this sale. %s',
                    coalesce(v_row.display_name, 'A member'), v_breach);
    end if;
  end loop;

  return null;
end;
$$;

create or replace function public.respond_to_order_line(
  p_line_id uuid,
  p_accept  boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line     record;
  v_breach   text;
  v_is_group boolean;
begin
  select ol.*, o.confirmation_deadline, l.cooperative_id
    into v_line
  from public.order_lines ol
  join public.orders o on o.id = ol.order_id
  join public.produce_listings l on l.id = ol.listing_id
  where ol.id = p_line_id
  for update of ol;

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

  v_is_group := v_line.cooperative_id is not null;

  -- Declining is never limited: being unverified must not trap anybody in a sale.
  if p_accept then
    if v_is_group then
      -- Each member against their own ceiling, not the officer's.
      v_breach := public.group_ceiling_breach(v_line.listing_id, v_line.line_total);
    else
      v_breach := public.kyc_ceiling_breach(v_line.farmer_id, v_line.line_total);
    end if;

    if v_breach is not null then
      raise exception '%', v_breach using errcode = 'insufficient_privilege';
    end if;
  end if;

  update public.order_lines
     set status = case when p_accept then 'confirmed' else 'declined' end::public.order_line_status,
         responded_at = now()
   where id = p_line_id;

  if not p_accept then
    update public.produce_listings set status = 'active' where id = v_line.listing_id;
  end if;

  perform public.refresh_order_status(v_line.order_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.listing_contributions enable row level security;

create policy "contributors read their own contribution"
  on public.listing_contributions for select to authenticated
  using ((select auth.uid()) = farmer_id);

create policy "officer reads contributions to their group's listings"
  on public.listing_contributions for select to authenticated
  using (exists (
    select 1 from public.produce_listings l
    where l.id = listing_contributions.listing_id
      and l.cooperative_id is not null
      and public.is_cooperative_officer(l.cooperative_id, (select auth.uid()))
  ));

-- FR-4: group listings show constituent member contributions. A buyer deciding
-- on a consolidated lot can see it is genuinely several members' produce.
create policy "buyers read contributions to offered listings"
  on public.listing_contributions for select to authenticated
  using (
    public.has_any_role('buyer', 'trading_desk', 'bagsakan_operator')
    and exists (
      select 1 from public.produce_listings l
      where l.id = listing_contributions.listing_id
        and l.status in ('active', 'committed')
    )
  );

create policy "compliance and admin read contributions"
  on public.listing_contributions for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

-- ---------------------------------------------------------------------------
-- A gap in the slice 2 policies, surfaced by the contributions test
-- ---------------------------------------------------------------------------
--
-- Buyers could read listings only while status = 'active', so the moment a buyer
-- reserved one it became invisible to them — including the listing they had just
-- committed to buy. Their order still showed the commodity and quantity, because
-- those are copied onto the order line, but the listing behind it was gone.
--
-- Safe to widen: it admits a buyer only to listings they already hold an order
-- line against, which is a thing they demonstrably know about.
create policy "buyers read listings they ordered"
  on public.produce_listings for select to authenticated
  using (exists (
    select 1 from public.order_lines ol
    where ol.listing_id = produce_listings.id
      and ol.buyer_id = (select auth.uid())
  ));

create policy "officer records contributions on a draft"
  on public.listing_contributions for all to authenticated
  using (exists (
    select 1 from public.produce_listings l
    where l.id = listing_contributions.listing_id
      and l.status = 'draft'
      and l.cooperative_id is not null
      and public.is_cooperative_officer(l.cooperative_id, (select auth.uid()))
  ))
  with check (exists (
    select 1 from public.produce_listings l
    where l.id = listing_contributions.listing_id
      and l.status = 'draft'
      and l.cooperative_id is not null
      and public.is_cooperative_officer(l.cooperative_id, (select auth.uid()))
  ));
