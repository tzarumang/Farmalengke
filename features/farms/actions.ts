'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import { farmInputSchema } from './schema';

export interface FarmFormState {
  error?: string;
  fieldErrors?: Record<string, string>;
}

/**
 * Registers a farm for the signed-in farmer.
 *
 * No farmer id is accepted from the form — it comes from the verified session, so
 * a crafted request cannot file a farm under somebody else's name. Row-level
 * security enforces the same thing again at the database.
 */
export async function createFarm(
  _previous: FarmFormState,
  formData: FormData,
): Promise<FarmFormState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const parsed = farmInputSchema.safeParse({
    name: formData.get('name'),
    regionCode: formData.get('regionCode'),
    barangay: formData.get('barangay'),
    cityMunicipality: formData.get('cityMunicipality'),
    province: formData.get('province'),
    areaValue: formData.get('areaValue') || undefined,
    areaUnit: formData.get('areaUnit') || undefined,
    shareLocation: formData.get('shareLocation') === 'on',
    latitude: formData.get('latitude') || undefined,
    longitude: formData.get('longitude') || undefined,
  });

  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const issue of parsed.error.issues) {
      const key = String(issue.path[0] ?? 'form');
      fieldErrors[key] ??= issue.message;
    }
    return { error: 'Check the highlighted fields.', fieldErrors };
  }

  const input = parsed.data;
  const sharingLocation = input.shareLocation && input.latitude !== undefined;

  const supabase = await createClient();
  const { error } = await supabase.from('farms').insert({
    farmer_id: userId,
    name: input.name,
    region_code: input.regionCode,
    barangay: input.barangay,
    city_municipality: input.cityMunicipality,
    province: input.province,
    area_value: input.areaValue ?? null,
    area_unit: input.areaUnit ?? null,
    // Consent and coordinates are written together or not at all, mirroring the
    // constraint in the database.
    gps_latitude: sharingLocation ? input.latitude : null,
    gps_longitude: sharingLocation ? input.longitude : null,
    gps_consent_at: sharingLocation ? new Date().toISOString() : null,
  });

  if (error) {
    return { error: 'Could not save the farm. Try again.' };
  }

  revalidatePath('/farms');
  redirect('/farms');
}
