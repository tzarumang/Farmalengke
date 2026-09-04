import 'server-only';

import { createClient } from '@/lib/supabase/server';
import { getVerifiedUserId } from '@/features/profile/data';

import type { Farm } from './schema';

interface FarmRow {
  id: string;
  name: string;
  region_code: string;
  barangay: string;
  city_municipality: string;
  province: string;
  area_value: string | number | null;
  area_unit: Farm['areaUnit'];
  gps_consent_at: string | null;
  created_at: string;
}

function toFarm(row: FarmRow): Farm {
  return {
    id: row.id,
    name: row.name,
    regionCode: row.region_code,
    barangay: row.barangay,
    cityMunicipality: row.city_municipality,
    province: row.province,
    // Postgres numeric arrives as a string; Number() here keeps the boundary in
    // one place rather than scattering coercion through the UI.
    areaValue: row.area_value === null ? null : Number(row.area_value),
    areaUnit: row.area_unit,
    hasSharedLocation: row.gps_consent_at !== null,
    createdAt: row.created_at,
  };
}

const FARM_COLUMNS =
  'id, name, region_code, barangay, city_municipality, province, area_value, area_unit, gps_consent_at, created_at';

export async function listOwnFarms(): Promise<Farm[]> {
  const userId = await getVerifiedUserId();
  if (!userId) return [];

  const supabase = await createClient();
  const { data, error } = await supabase
    .from('farms')
    .select(FARM_COLUMNS)
    .eq('farmer_id', userId)
    .order('created_at', { ascending: false });

  if (error || !data) return [];
  return (data as FarmRow[]).map(toFarm);
}

export async function getOwnFarm(farmId: string): Promise<Farm | null> {
  const userId = await getVerifiedUserId();
  if (!userId) return null;

  const supabase = await createClient();
  const { data, error } = await supabase
    .from('farms')
    .select(FARM_COLUMNS)
    .eq('id', farmId)
    .eq('farmer_id', userId)
    .maybeSingle<FarmRow>();

  if (error || !data) return null;
  return toFarm(data);
}
