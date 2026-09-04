import 'server-only';

import { createClient } from '@/lib/supabase/server';

import type { Profile } from './schema';

/**
 * Server-only data access for profiles.
 *
 * Every function re-verifies the caller rather than assuming the page already did.
 * Row-level security would stop a cross-user read anyway, but defence that depends on
 * exactly one layer is defence that fails when that layer is misconfigured.
 */

interface ProfileRow {
  id: string;
  mobile_number: string;
  display_name: string | null;
  preferred_language: string;
  barangay: string | null;
  city_municipality: string | null;
  province: string | null;
  kyc_tier: Profile['kycTier'];
  status: Profile['status'];
}

function toProfile(row: ProfileRow, roles: string[]): Profile {
  return {
    id: row.id,
    mobileNumber: row.mobile_number,
    displayName: row.display_name,
    preferredLanguage: row.preferred_language,
    barangay: row.barangay,
    cityMunicipality: row.city_municipality,
    province: row.province,
    kycTier: row.kyc_tier,
    status: row.status,
    roles,
  };
}

/** The signed-in user's id, verified against the JWT signature. */
export async function getVerifiedUserId(): Promise<string | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getClaims();
  if (error || !data?.claims) return null;
  return typeof data.claims.sub === 'string' ? data.claims.sub : null;
}

/** Roles come from the token, which the access token hook populates from user_roles. */
export async function getVerifiedRoles(): Promise<string[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getClaims();
  if (error || !data?.claims) return [];

  const appMetadata = data.claims.app_metadata;
  if (!appMetadata || typeof appMetadata !== 'object') return [];

  const roles = (appMetadata as { roles?: unknown }).roles;
  return Array.isArray(roles) ? roles.filter((r): r is string => typeof r === 'string') : [];
}

export async function getOwnProfile(): Promise<Profile | null> {
  const userId = await getVerifiedUserId();
  if (!userId) return null;

  const supabase = await createClient();
  const { data, error } = await supabase
    .from('profiles')
    .select(
      'id, mobile_number, display_name, preferred_language, barangay, city_municipality, province, kyc_tier, status',
    )
    .eq('id', userId)
    .maybeSingle<ProfileRow>();

  if (error || !data) return null;

  return toProfile(data, await getVerifiedRoles());
}

/**
 * Creates the profile row that accompanies a newly authenticated phone number.
 *
 * Called on first visit rather than by a database trigger on auth.users, so that the
 * insert runs as the user and is therefore subject to the same RLS policy as any
 * other write. A trigger would run as the auth admin and bypass it.
 */
export async function ensureOwnProfile(mobileNumber: string): Promise<Profile | null> {
  const userId = await getVerifiedUserId();
  if (!userId) return null;

  const existing = await getOwnProfile();
  if (existing) return existing;

  const supabase = await createClient();
  const { error } = await supabase
    .from('profiles')
    .insert({ id: userId, mobile_number: mobileNumber });

  if (error) return null;

  return getOwnProfile();
}
