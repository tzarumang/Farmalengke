import 'server-only';

import { getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import type { Cooperative, Invitation, Member } from './schema';

interface MembershipRow {
  id: string;
  cooperative_id: string;
  farmer_id: string;
  status: Member['status'];
  invited_at: string;
  profiles: { display_name: string | null; mobile_number: string } | { display_name: string | null; mobile_number: string }[] | null;
  cooperatives: { name: string } | { name: string }[] | null;
}

interface CooperativeRow {
  id: string;
  name: string;
  officer_id: string;
  region_code: string;
  barangay: string;
  city_municipality: string;
  province: string;
}

function one<T>(value: T | T[] | null | undefined): T | null {
  if (!value) return null;
  return Array.isArray(value) ? (value[0] ?? null) : value;
}

/**
 * The cooperatives the signed-in person belongs to, with their members.
 *
 * Row-level security limits both queries to groups the caller is actually in, so
 * this returns nothing for an unrelated farmer however it is called.
 */
export async function listOwnCooperatives(): Promise<Cooperative[]> {
  const userId = await getVerifiedUserId();
  if (!userId) return [];

  const supabase = await createClient();

  const { data: coops, error } = await supabase
    .from('cooperatives')
    .select('id, name, officer_id, region_code, barangay, city_municipality, province')
    .order('name');

  if (error || !coops || coops.length === 0) return [];

  const rows = coops as unknown as CooperativeRow[];

  const { data: memberships } = await supabase
    .from('cooperative_memberships')
    .select('id, cooperative_id, farmer_id, status, invited_at, profiles(display_name, mobile_number)')
    .in('cooperative_id', rows.map((c) => c.id));

  const byCooperative = new Map<string, Member[]>();
  for (const row of (memberships ?? []) as unknown as MembershipRow[]) {
    const profile = one(row.profiles);
    const list = byCooperative.get(row.cooperative_id) ?? [];
    list.push({
      membershipId: row.id,
      farmerId: row.farmer_id,
      displayName: profile?.display_name ?? null,
      mobileNumber: profile?.mobile_number ?? '',
      status: row.status,
      invitedAt: row.invited_at,
    });
    byCooperative.set(row.cooperative_id, list);
  }

  return rows.map((row) => ({
    id: row.id,
    name: row.name,
    officerId: row.officer_id,
    regionCode: row.region_code,
    barangay: row.barangay,
    cityMunicipality: row.city_municipality,
    province: row.province,
    isOfficer: row.officer_id === userId,
    members: byCooperative.get(row.id) ?? [],
  }));
}

/** Invitations awaiting this farmer's answer. */
export async function listOwnInvitations(): Promise<Invitation[]> {
  const userId = await getVerifiedUserId();
  if (!userId) return [];

  const supabase = await createClient();
  const { data, error } = await supabase
    .from('cooperative_memberships')
    .select('id, cooperative_id, invited_at, cooperatives(name)')
    .eq('farmer_id', userId)
    .eq('status', 'invited')
    .order('invited_at', { ascending: false });

  if (error || !data) return [];

  return (data as unknown as MembershipRow[]).map((row) => ({
    membershipId: row.id,
    cooperativeId: row.cooperative_id,
    cooperativeName: one(row.cooperatives)?.name ?? 'A group',
    invitedAt: row.invited_at,
  }));
}
