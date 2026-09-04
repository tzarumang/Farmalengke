-- M2 slice 2: a farmer's asking price on a listing.
--
-- CHANGE TO THE PRD. FR-5 as drafted captures no price; the client decided that a
-- marketplace order transacts at a price the farmer sets, so the field is added
-- here and FR-5's acceptance criteria updated to match. The platform's published
-- price (FR-9) remains the benchmark a farmer judges against, not the transaction
-- price for a third-party sale.

alter table public.produce_listings
  add column asking_price        numeric(12, 2),
  add column asking_price_per_kg numeric(12, 4),
  add column currency            text not null default 'PHP';

-- Any listing already offered has no price, because the column did not exist
-- until a moment ago. Adding the constraint would fail against that data, so
-- those listings return to draft: the farmer sets a price and offers again.
-- Withdrawing an offer is the safe direction — the alternative is inventing a
-- price on somebody's behalf.
update public.produce_listings
   set status = 'draft'
 where status = 'active'
   and asking_price is null;

alter table public.produce_listings
  add constraint produce_listings_asking_price_positive
    check (asking_price is null or asking_price > 0),
  add constraint produce_listings_currency
    check (currency ~ '^[A-Z]{3}$'),
  -- Nothing can be offered to buyers without a price on it. A draft may still be
  -- saved without one, so a farmer can start a listing before deciding.
  add constraint produce_listings_offered_needs_price
    check (status <> 'active' or asking_price is not null);

comment on column public.produce_listings.asking_price is
  'Per one unit_code — the same unit the quantity is entered in, so the farmer '
  'quotes in the terms they think in.';
comment on column public.produce_listings.asking_price_per_kg is
  'Derived at write time from the recorded conversion, for comparison across '
  'listings quoted in different units.';

-- Extend the existing normalisation trigger to cover price as well as quantity.
-- Deriving per-kilo pricing on read would let a later conversion correction
-- silently restate a price a buyer already agreed to.
create or replace function public.set_listing_quantity_kg()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_region text;
  v_factor numeric;
begin
  select f.region_code into v_region
  from public.farms f
  where f.id = new.farm_id;

  v_factor := public.commodity_unit_to_kg(new.commodity_id, new.unit_code, v_region);

  if v_factor is null then
    raise exception
      'no kilogram conversion on record for this commodity in unit % (region %)',
      new.unit_code, coalesce(v_region, 'any')
      using errcode = 'check_violation';
  end if;

  new.quantity_kg := round(new.quantity * v_factor, 3);

  -- A price quoted per sack becomes a price per kilo by dividing, not multiplying.
  new.asking_price_per_kg := case
    when new.asking_price is null then null
    else round(new.asking_price / v_factor, 4)
  end;

  return new;
end;
$$;

drop trigger if exists produce_listings_set_quantity_kg on public.produce_listings;
create trigger produce_listings_set_quantity_kg
  before insert or update of quantity, unit_code, commodity_id, farm_id, asking_price
  on public.produce_listings
  for each row execute function public.set_listing_quantity_kg();

-- Supports the buyer's browse filters (FR-7): active listings by commodity, with
-- price and availability to sort and filter on.
create index produce_listings_browse_price_idx
  on public.produce_listings (commodity_id, asking_price_per_kg, available_from)
  where status = 'active';
