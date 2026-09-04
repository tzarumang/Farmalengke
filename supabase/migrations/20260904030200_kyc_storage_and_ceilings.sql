-- M2 slice 3: the private bucket for identity documents, and enforcement of the
-- tier ceilings on the order path.

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------
--
-- A private bucket. Paths are `{subject_id}/{submission_id}/{document_type}`, so
-- the owning person is the first path segment and a policy can check it without
-- reading any table.

insert into storage.buckets (id, name, public)
values ('kyc-documents', 'kyc-documents', false)
on conflict (id) do nothing;

-- Stated, not assumed. Hosted Supabase enables this by default; a self-hosted
-- instance that did not would leave the policies below present but unenforced,
-- and every identity document readable by any signed-in user.
alter table storage.objects enable row level security;

-- Supabase's own policies live on storage.objects; these narrow it to the bucket.
create policy "read own kyc documents"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'kyc-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "compliance reads kyc documents"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'kyc-documents'
    and public.has_any_role('compliance', 'admin')
  );

create policy "upload own kyc documents"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'kyc-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- A subject may withdraw a document they uploaded. Compliance deliberately
-- cannot delete: a reviewer removing the evidence they decided on would leave an
-- unauditable decision, and §9's retention is a scheduled destruction rather
-- than an ad-hoc one.
create policy "delete own kyc documents"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'kyc-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- ---------------------------------------------------------------------------
-- Ceilings on the order path
-- ---------------------------------------------------------------------------
--
-- Both sides of a trade are checked, at the moment each one commits: the buyer
-- when they place the order, the farmer when they confirm their line. Checking
-- only at placement would let an unverified farmer accept any amount.

create or replace function public.place_order(
  p_listing_ids       uuid[],
  p_delivery_date     date,
  p_delivery_barangay text,
  p_delivery_city     text,
  p_delivery_province text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer   uuid := auth.uid();
  v_order   uuid;
  v_window  int;
  v_listing record;
  v_total   numeric(14, 2) := 0;
  v_count   int := 0;
  v_breach  text;
begin
  if v_buyer is null then
    raise exception 'not signed in' using errcode = 'insufficient_privilege';
  end if;

  if not public.has_any_role('buyer', 'trading_desk', 'admin') then
    raise exception 'only a buyer may place an order'
      using errcode = 'insufficient_privilege';
  end if;

  if p_listing_ids is null or array_length(p_listing_ids, 1) is null then
    raise exception 'an order needs at least one listing' using errcode = 'check_violation';
  end if;

  if p_delivery_date < current_date then
    raise exception 'the delivery date cannot be in the past' using errcode = 'check_violation';
  end if;

  -- Price the order before committing to anything, so the ceiling is checked
  -- against the real total rather than a running one.
  select coalesce(sum(round(l.quantity_kg * l.asking_price_per_kg, 2)), 0)
    into v_total
  from public.produce_listings l
  where l.id = any (p_listing_ids)
    and l.status = 'active'
    and l.asking_price_per_kg is not null;

  v_breach := public.kyc_ceiling_breach(v_buyer, v_total);
  if v_breach is not null then
    raise exception '%', v_breach using errcode = 'insufficient_privilege';
  end if;

  v_window := public.setting_int('order_confirmation_window_hours', 24);

  insert into public.orders (
    buyer_id, delivery_date, delivery_barangay, delivery_city, delivery_province,
    confirmation_deadline
  )
  values (
    v_buyer, p_delivery_date, p_delivery_barangay, p_delivery_city, p_delivery_province,
    now() + make_interval(hours => v_window)
  )
  returning id into v_order;

  v_total := 0;

  for v_listing in
    select l.id, l.farmer_id, l.quantity_kg, l.asking_price_per_kg, l.status
    from public.produce_listings l
    where l.id = any (p_listing_ids)
    for update
  loop
    if v_listing.status <> 'active' then
      raise exception 'listing % is no longer available', v_listing.id
        using errcode = 'check_violation';
    end if;

    if v_listing.asking_price_per_kg is null then
      raise exception 'listing % has no asking price', v_listing.id
        using errcode = 'check_violation';
    end if;

    insert into public.order_lines (
      order_id, listing_id, farmer_id, buyer_id, quantity_kg, price_per_kg, line_total
    )
    values (
      v_order, v_listing.id, v_listing.farmer_id, v_buyer,
      v_listing.quantity_kg, v_listing.asking_price_per_kg,
      round(v_listing.quantity_kg * v_listing.asking_price_per_kg, 2)
    );

    update public.produce_listings set status = 'committed' where id = v_listing.id;

    v_total := v_total + round(v_listing.quantity_kg * v_listing.asking_price_per_kg, 2);
    v_count := v_count + 1;
  end loop;

  if v_count <> array_length(p_listing_ids, 1) then
    raise exception 'one or more listings could not be found' using errcode = 'check_violation';
  end if;

  update public.orders set total_price = v_total where id = v_order;

  return v_order;
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
  v_line   record;
  v_breach text;
begin
  select ol.*, o.confirmation_deadline
    into v_line
  from public.order_lines ol
  join public.orders o on o.id = ol.order_id
  where ol.id = p_line_id
  for update;

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

  -- Only accepting is limited. Declining moves no money, so a farmer at any tier
  -- may always say no — being unverified must never trap somebody in a sale.
  if p_accept then
    v_breach := public.kyc_ceiling_breach(v_line.farmer_id, v_line.line_total);
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
