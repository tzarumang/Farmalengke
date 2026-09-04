import 'server-only';

import { getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import type { Listing } from './schema';

interface ListingRow {
  id: string;
  variety: string | null;
  quantity: string | number;
  unit_code: string;
  quantity_kg: string | number;
  claimed_grade: string | null;
  availability: Listing['availability'];
  available_from: string | null;
  status: Listing['status'];
  created_at: string;
  farms: { name: string } | null;
  commodities: { name_en: string; name_fil: string } | null;
}

const LISTING_COLUMNS = `
  id, variety, quantity, unit_code, quantity_kg, claimed_grade,
  availability, available_from, status, created_at,
  farms(name),
  commodities(name_en, name_fil)
`;

function toListing(row: ListingRow): Listing {
  return {
    id: row.id,
    farmName: row.farms?.name ?? 'Unknown farm',
    commodityNameEn: row.commodities?.name_en ?? 'Unknown',
    commodityNameFil: row.commodities?.name_fil ?? 'Unknown',
    variety: row.variety,
    quantity: Number(row.quantity),
    unitCode: row.unit_code,
    quantityKg: Number(row.quantity_kg),
    claimedGrade: row.claimed_grade,
    availability: row.availability,
    availableFrom: row.available_from,
    status: row.status,
    createdAt: row.created_at,
  };
}

export async function listOwnListings(): Promise<Listing[]> {
  const userId = await getVerifiedUserId();
  if (!userId) return [];

  const supabase = await createClient();
  const { data, error } = await supabase
    .from('produce_listings')
    .select(LISTING_COLUMNS)
    .eq('farmer_id', userId)
    .order('created_at', { ascending: false });

  if (error || !data) return [];
  return (data as unknown as ListingRow[]).map(toListing);
}
