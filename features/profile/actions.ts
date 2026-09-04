'use server';

import { revalidatePath } from 'next/cache';

import { createClient } from '@/lib/supabase/server';

import { getVerifiedUserId } from './data';
import { updateProfileSchema } from './schema';

export interface ProfileFormState {
  error?: string;
  saved?: boolean;
}

/**
 * Updates the caller's own profile.
 *
 * Note what is *not* here: no user id is accepted from the form. Taking one would let
 * an attacker edit somebody else's row by changing a hidden field. The id comes from
 * the verified session, and RLS enforces the same thing again at the database.
 */
export async function updateOwnProfile(
  _previous: ProfileFormState,
  formData: FormData,
): Promise<ProfileFormState> {
  const userId = await getVerifiedUserId();
  if (!userId) {
    return { error: 'Your session has expired. Sign in again.' };
  }

  const parsed = updateProfileSchema.safeParse({
    displayName: formData.get('displayName'),
    preferredLanguage: formData.get('preferredLanguage'),
    barangay: formData.get('barangay'),
    cityMunicipality: formData.get('cityMunicipality'),
    province: formData.get('province'),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? 'Check the form and try again.' };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from('profiles')
    .update({
      display_name: parsed.data.displayName,
      preferred_language: parsed.data.preferredLanguage,
      barangay: parsed.data.barangay || null,
      city_municipality: parsed.data.cityMunicipality || null,
      province: parsed.data.province || null,
    })
    .eq('id', userId);

  if (error) {
    return { error: 'Could not save your details. Try again.' };
  }

  revalidatePath('/profile');
  return { saved: true };
}
