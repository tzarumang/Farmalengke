import 'server-only';

import { createClient } from '@/lib/supabase/server';

/**
 * Reference data: regions, commodities, and trade units.
 *
 * Readable by any signed-in user and writable only by an administrator, which is
 * enforced by policy rather than here — a farmer able to edit a unit conversion
 * could edit what they are paid.
 */

import type { Commodity, Region, TradeUnit } from './types';

export type { Commodity, Region, TradeUnit };

interface CommodityRow {
  id: string;
  code: string;
  name_en: string;
  name_fil: string;
}

interface TradeUnitRow {
  code: string;
  name_en: string;
  name_fil: string;
}

/**
 * A PostgREST embed may arrive as a single row, an array, or null.
 *
 * Without generated database types the client cannot tell a to-one relation from
 * a to-many one, so normalise the shape once here rather than letting the
 * ambiguity leak into every caller.
 */
function asRows<T>(value: T | T[] | null | undefined): T[] {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

function toCommodity(row: CommodityRow): Commodity {
  return { id: row.id, code: row.code, nameEn: row.name_en, nameFil: row.name_fil };
}

export async function listRegions(): Promise<Region[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('regions')
    .select('code, name')
    .eq('is_active', true)
    .order('name');

  if (error || !data) return [];
  return (data as unknown as { code: string; name: string }[]).map((r) => ({
    code: r.code,
    name: r.name,
  }));
}

/** Commodities, optionally narrowed to those a region actually trades. */
export async function listCommodities(regionCode?: string): Promise<Commodity[]> {
  const supabase = await createClient();

  if (regionCode) {
    const { data, error } = await supabase
      .from('region_commodities')
      .select('commodities(id, code, name_en, name_fil)')
      .eq('region_code', regionCode);

    if (error || !data) return [];

    const rows = data as unknown as {
      commodities: CommodityRow | CommodityRow[] | null;
    }[];

    return rows
      .flatMap((row) => asRows(row.commodities))
      .map(toCommodity)
      .sort((a, b) => a.nameEn.localeCompare(b.nameEn));
  }

  const { data, error } = await supabase
    .from('commodities')
    .select('id, code, name_en, name_fil')
    .eq('is_active', true)
    .order('name_en');

  if (error || !data) return [];
  return (data as unknown as CommodityRow[]).map(toCommodity);
}

/**
 * The units a commodity has a recorded kilogram conversion for.
 *
 * Only these are offered. A unit with no conversion cannot be normalised, and the
 * database refuses the write rather than guessing a weight — so offering it in the
 * interface would only produce a dead end.
 */
export async function listUnitsForCommodity(
  commodityId: string,
  regionCode: string | null,
): Promise<TradeUnit[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('commodity_units')
    .select('unit_code, region_code, trade_units(code, name_en, name_fil)')
    .eq('commodity_id', commodityId);

  if (error || !data) return [];

  const rows = data as unknown as {
    region_code: string | null;
    trade_units: TradeUnitRow | TradeUnitRow[] | null;
  }[];

  const seen = new Set<string>();
  const units: TradeUnit[] = [];

  for (const row of rows) {
    // A conversion with no region applies everywhere; a region-specific one
    // applies only to its own region.
    if (row.region_code !== null && row.region_code !== regionCode) continue;

    for (const unit of asRows(row.trade_units)) {
      if (seen.has(unit.code)) continue;
      seen.add(unit.code);
      units.push({ code: unit.code, nameEn: unit.name_en, nameFil: unit.name_fil });
    }
  }

  return units;
}
