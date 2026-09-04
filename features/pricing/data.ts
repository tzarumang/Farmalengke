import 'server-only';

import { createClient } from '@/lib/supabase/server';

import { STALE_AFTER_HOURS, type PriceView } from './schema';

/**
 * The platform's published buying price, with its history.
 *
 * FR-6 is strict about provenance: no price is shown without a source and a
 * timestamp, and anything older than 48 hours is marked stale. So every figure
 * returned here carries where it came from and when.
 *
 * The "recent market prices" FR-6 also asks for currently means the platform's own
 * published history. External sources (DA, other trading posts) are a later
 * integration listed in PRD §10; until one exists, showing an external figure
 * would mean showing a number we cannot attribute.
 */

const PLATFORM_SOURCE = 'Farmalengke platform bid';

interface PriceRow {
  commodity_id: string;
  price_per_kg: string | number;
  currency: string;
  effective_from: string;
  commodities: { name_en: string; name_fil: string } | { name_en: string; name_fil: string }[] | null;
}

function one<T>(value: T | T[] | null | undefined): T | null {
  if (!value) return null;
  return Array.isArray(value) ? (value[0] ?? null) : value;
}

/** Price views for a set of commodities in one region. */
export async function getPriceViews(
  commodityIds: string[],
  regionCode: string,
): Promise<PriceView[]> {
  if (commodityIds.length === 0) return [];

  const supabase = await createClient();
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  // RLS already hides prices that have not taken effect from anyone but the
  // trading desk, so this is the published history as the caller may see it.
  const { data, error } = await supabase
    .from('platform_prices')
    .select('commodity_id, price_per_kg, currency, effective_from, commodities(name_en, name_fil)')
    .in('commodity_id', commodityIds)
    .eq('region_code', regionCode)
    .gte('effective_from', sevenDaysAgo)
    .order('effective_from', { ascending: false });

  if (error || !data) return [];

  const rows = data as unknown as PriceRow[];
  const byCommodity = new Map<string, PriceRow[]>();
  for (const row of rows) {
    const list = byCommodity.get(row.commodity_id) ?? [];
    list.push(row);
    byCommodity.set(row.commodity_id, list);
  }

  const views: PriceView[] = [];

  for (const commodityId of commodityIds) {
    const history = byCommodity.get(commodityId) ?? [];
    const latest = history[0];
    const names = one(latest?.commodities);

    if (!latest) {
      // Nothing published in the window. Say so rather than invent a figure.
      views.push({
        commodityId,
        commodityNameEn: '',
        commodityNameFil: '',
        regionCode,
        current: null,
        sevenDayLow: null,
        sevenDayHigh: null,
        isStale: false,
      });
      continue;
    }

    const prices = history.map((r) => Number(r.price_per_kg));
    const ageHours =
      (Date.now() - new Date(latest.effective_from).getTime()) / (1000 * 60 * 60);

    views.push({
      commodityId,
      commodityNameEn: names?.name_en ?? '',
      commodityNameFil: names?.name_fil ?? '',
      regionCode,
      current: {
        pricePerKg: Number(latest.price_per_kg),
        currency: latest.currency,
        source: PLATFORM_SOURCE,
        observedAt: latest.effective_from,
      },
      sevenDayLow: Math.min(...prices),
      sevenDayHigh: Math.max(...prices),
      isStale: ageHours > STALE_AFTER_HOURS,
    });
  }

  return views;
}

/** Every published price for the trading desk, including scheduled ones. */
export async function listPublishedPrices(limit = 50) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('platform_prices')
    .select('id, price_per_kg, currency, grade, region_code, effective_from, commodities(name_en)')
    .order('effective_from', { ascending: false })
    .limit(limit);

  if (error || !data) return [];

  return (data as unknown as (PriceRow & { id: string; grade: string | null; region_code: string })[]).map(
    (row) => ({
      id: row.id,
      commodityName: one(row.commodities)?.name_en ?? 'Unknown',
      grade: row.grade,
      regionCode: row.region_code,
      pricePerKg: Number(row.price_per_kg),
      currency: row.currency,
      effectiveFrom: row.effective_from,
      isScheduled: new Date(row.effective_from).getTime() > Date.now(),
    }),
  );
}
