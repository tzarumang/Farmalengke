'use server';

import { revalidatePath } from 'next/cache';

import { getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import { cooperativeInputSchema, inviteInputSchema } from './schema';

export interface CooperativeState {
  error?: string;
  message?: string;
  fieldErrors?: Record<string, string>;
}

function collectFieldErrors(issues: { path: PropertyKey[]; message: string }[]) {
  const fieldErrors: Record<string, string> = {};
  for (const issue of issues) {
    const key = String(issue.path[0] ?? 'form');
    fieldErrors[key] ??= issue.message;
  }
  return fieldErrors;
}

/**
 * Registers a group, with the signed-in person as its officer.
 *
 * The officer is taken from the session rather than the form: registering a
 * group in somebody else's name would make them answerable for something they
 * never agreed to. The insert policy enforces the same thing.
 */
export async function createCooperative(
  _previous: CooperativeState,
  formData: FormData,
): Promise<CooperativeState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const parsed = cooperativeInputSchema.safeParse({
    name: formData.get('name'),
    regionCode: formData.get('regionCode'),
    barangay: formData.get('barangay'),
    cityMunicipality: formData.get('cityMunicipality'),
    province: formData.get('province'),
  });

  if (!parsed.success) {
    return {
      error: 'Check the highlighted fields.',
      fieldErrors: collectFieldErrors(parsed.error.issues),
    };
  }

  const supabase = await createClient();
  const { error } = await supabase.from('cooperatives').insert({
    name: parsed.data.name,
    officer_id: userId,
    region_code: parsed.data.regionCode,
    barangay: parsed.data.barangay,
    city_municipality: parsed.data.cityMunicipality,
    province: parsed.data.province,
  });

  if (error) return { error: 'Could not register the group. Try again.' };

  revalidatePath('/cooperative');
  return { message: 'Group registered. You can invite members now.' };
}

/**
 * Invites a farmer by mobile number.
 *
 * Only ever creates an invitation — never a membership. FR-4 requires the farmer
 * to accept, and the insert policy refuses any status but `invited`, so an
 * officer cannot enrol somebody who has not said yes.
 */
export async function inviteMember(
  _previous: CooperativeState,
  formData: FormData,
): Promise<CooperativeState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const parsed = inviteInputSchema.safeParse({
    cooperativeId: formData.get('cooperativeId'),
    mobileNumber: formData.get('mobileNumber'),
  });

  if (!parsed.success) {
    return {
      error: parsed.error.issues[0]?.message ?? 'Check the number and try again.',
      fieldErrors: collectFieldErrors(parsed.error.issues),
    };
  }

  const supabase = await createClient();

  const { data: profile } = await supabase
    .from('profiles')
    .select('id')
    .eq('mobile_number', parsed.data.mobileNumber)
    .maybeSingle<{ id: string }>();

  if (!profile) {
    // Deliberately the same message whether or not the number is registered:
    // an officer must not be able to use invitations to discover who has an
    // account here.
    return {
      error:
        'We could not invite that number. Check it, and ask them to sign up first if they have not.',
    };
  }

  const { error } = await supabase.from('cooperative_memberships').insert({
    cooperative_id: parsed.data.cooperativeId,
    farmer_id: profile.id,
    status: 'invited',
    invited_by: userId,
  });

  if (error) {
    if (/duplicate key/i.test(error.message)) {
      return { error: 'That farmer is already invited or already a member.' };
    }
    return { error: 'Could not send the invitation. Try again.' };
  }

  revalidatePath('/cooperative');
  return { message: 'Invitation sent. They have to accept before they join.' };
}

export async function respondToInvitation(
  _previous: CooperativeState,
  formData: FormData,
): Promise<CooperativeState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const membershipId = String(formData.get('membershipId') ?? '');
  const accept = formData.get('decision') === 'accept';
  if (!membershipId) return { error: 'Missing invitation.' };

  const supabase = await createClient();
  const { error } = await supabase.rpc('respond_to_invitation', {
    p_membership_id: membershipId,
    p_accept: accept,
  });

  if (error) {
    if (/already been answered/i.test(error.message)) {
      return { error: 'That invitation has already been answered.' };
    }
    return { error: 'Could not record your answer. Try again.' };
  }

  revalidatePath('/cooperative');
  return { message: accept ? 'You have joined the group.' : 'Invitation declined.' };
}

export async function leaveCooperative(
  _previous: CooperativeState,
  formData: FormData,
): Promise<CooperativeState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const membershipId = String(formData.get('membershipId') ?? '');
  if (!membershipId) return { error: 'Missing membership.' };

  const supabase = await createClient();
  const { error } = await supabase.rpc('leave_cooperative', {
    p_membership_id: membershipId,
  });

  if (error) {
    if (/officer cannot leave/i.test(error.message)) {
      return {
        error:
          'You are the officer, so you cannot leave. Hand the role to another member first.',
      };
    }
    return { error: 'Could not leave the group. Try again.' };
  }

  revalidatePath('/cooperative');
  return { message: 'You have left the group.' };
}
