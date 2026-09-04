import 'server-only';

import { createClient } from '@/lib/supabase/server';

/**
 * Buyer-facing browse over offered produce (FR-7).
 *
 * Row-level security already restricts this to active listings for buying roles,
 * so a buyer physically cannot read a draft or somebody's withdrawn listing. The
 * filters here narrow what they asked for; they are not the access control.
 */

import type { MarketFilters, MarketListing } from './types';

export type { MarketFilters, MarketListing };

interface MarketRow {
  id: string;
  variety: string | null;
  quantity: string | number;
  unit_code: string;
  quantity_kg: string | number;
  asking_price_per_kg: string | number | null;
  currency: string;
  claimed_grade: string | null;
  availability: MarketListing['availability'];
  available_from: string | null;
  commodities: { name_en: string; name_fil: string } | { name_en: string; name_fil: string }[] | null;
  farms:
    | { barangay: string; city_municipality: string; province: string; region_code: string }
    | { barangay: string; city_municipality: string; province: string; region_code: string }[]
    | null;
}

function one<T>(value: T | T[] | null | undefined): T | null {
  if (!value) return null;
  return Array.isArray(value) ? (value[0] ?? null) : value;
}

export async function browseListings(filters: MarketFilters = {}): Promise<MarketListing[]> {
  const supabase = await createClient();

  // Sweep lapsed reservations first, so a listing whose confirmation window has
  // closed is offered again immediately rather than only after a scheduled job.
  await supabase.rpc('expire_lapsed_reservations');

  let query = supabase
    .from('produce_listings')
    .select(
      `id, variety, quantity, unit_code, quantity_kg, asking_price_per_kg, currency,
       claimed_grade, availability, available_from,
       commodities(name_en, name_fil),
       farms!inner(barangay, city_municipality, province, region_code)`,
    )
    .eq('status', 'active')
    .order('available_from', { ascending: true, nullsFirst: true });

  if (filters.commodityId) query = query.eq('commodity_id', filters.commodityId);
  if (filters.regionCode) query = query.eq('farms.region_code', filters.regionCode);
  if (filters.minQuantityKg !== undefined) {
    query = query.gte('quantity_kg', filters.minQuantityKg);
  }
  if (filters.availableBy) query = query.lte('available_from', filters.availableBy);

  const { data, error } = await query;
  if (error || !data) return [];

  return (data as unknown as MarketRow[])
    .map((row) => {
      const commodity = one(row.commodities);
      const farm = one(row.farms);
      const pricePerKg = row.asking_price_per_kg === null ? 0 : Number(row.asking_price_per_kg);
      const quantityKg = Number(row.quantity_kg);

      return {
        id: row.id,
        commodityNameEn: commodity?.name_en ?? 'Unknown',
        commodityNameFil: commodity?.name_fil ?? 'Unknown',
        variety: row.variety,
        quantity: Number(row.quantity),
        unitCode: row.unit_code,
        quantityKg,
        askingPricePerKg: pricePerKg,
        lineTotal: Math.round(quantityKg * pricePerKg * 100) / 100,
        currency: row.currency,
        claimedGrade: row.claimed_grade,
        availability: row.availability,
        availableFrom: row.available_from,
        barangay: farm?.barangay ?? '',
        cityMunicipality: farm?.city_municipality ?? '',
        province: farm?.province ?? '',
        regionCode: farm?.region_code ?? '',
      };
    })
    // A listing with no price cannot be bought; the database forbids offering one,
    // so this only guards against a row that slipped through some other path.
    .filter((listing) => listing.askingPricePerKg > 0);
}
