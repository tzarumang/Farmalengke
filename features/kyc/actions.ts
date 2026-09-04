'use server';

import { revalidatePath } from 'next/cache';

import { getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import {
  documentStoragePath,
  KYC_DOCUMENT_TYPES,
  type KycDocumentType,
  type KycTier,
} from './schema';

export interface KycState {
  error?: string;
  message?: string;
  submissionId?: string;
}

/** Starts (or returns) a draft application for a tier. */
export async function startSubmission(
  _previous: KycState,
  formData: FormData,
): Promise<KycState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const tier = String(formData.get('requestedTier') ?? '') as KycTier;
  if (tier !== 'tier_1' && tier !== 'tier_2') {
    return { error: 'Choose which level of verification you want.' };
  }

  const supabase = await createClient();

  // One live application per tier, so re-entering the page resumes rather than
  // opening a second request for the same thing.
  const { data: existing } = await supabase
    .from('kyc_submissions')
    .select('id')
    .eq('subject_id', userId)
    .eq('requested_tier', tier)
    .in('status', ['draft', 'submitted'])
    .maybeSingle<{ id: string }>();

  if (existing) {
    revalidatePath('/verify');
    return { submissionId: existing.id };
  }

  const { data, error } = await supabase
    .from('kyc_submissions')
    .insert({ subject_id: userId, requested_tier: tier, status: 'draft' })
    .select('id')
    .single<{ id: string }>();

  if (error || !data) return { error: 'Could not start the application. Try again.' };

  revalidatePath('/verify');
  return { submissionId: data.id };
}

/**
 * Records that a document has been uploaded.
 *
 * The path is recomputed here from the session user rather than taken from the
 * client, so a caller cannot register somebody else's file as their own evidence.
 * The storage policy independently refuses a write outside the caller's folder,
 * so the two have to agree.
 */
export async function recordDocument(
  _previous: KycState,
  formData: FormData,
): Promise<KycState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const submissionId = String(formData.get('submissionId') ?? '');
  const documentType = String(formData.get('documentType') ?? '') as KycDocumentType;

  if (!submissionId) return { error: 'Missing application.' };
  if (!KYC_DOCUMENT_TYPES.includes(documentType)) {
    return { error: 'Unknown document type.' };
  }

  const supabase = await createClient();
  const { error } = await supabase.from('kyc_documents').upsert(
    {
      submission_id: submissionId,
      document_type: documentType,
      storage_path: documentStoragePath(userId, submissionId, documentType),
    },
    { onConflict: 'submission_id,document_type' },
  );

  if (error) return { error: 'Could not record the document. Try again.' };

  revalidatePath('/verify');
  return { message: 'Saved.' };
}

export async function sendForReview(
  _previous: KycState,
  formData: FormData,
): Promise<KycState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const submissionId = String(formData.get('submissionId') ?? '');
  if (!submissionId) return { error: 'Missing application.' };

  const supabase = await createClient();
  const { error } = await supabase.rpc('submit_kyc', { p_submission_id: submissionId });

  if (error) {
    // "still needed: ..." lists exactly what is missing, which is what FR-2 asks
    // the person to be told. Pass it through instead of replacing it.
    if (/still needed/i.test(error.message)) return { error: error.message };
    return { error: 'Could not send the application. Try again.' };
  }

  revalidatePath('/verify');
  return { message: 'Sent. We will check it and let you know.' };
}

export async function reviewSubmission(
  _previous: KycState,
  formData: FormData,
): Promise<KycState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const submissionId = String(formData.get('submissionId') ?? '');
  const approve = formData.get('decision') === 'approve';
  const reason = String(formData.get('reason') ?? '').trim();

  if (!submissionId) return { error: 'Missing application.' };
  if (!approve && reason.length === 0) {
    return { error: 'Say what was wrong, so they know what to send instead.' };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc('review_kyc', {
    p_submission_id: submissionId,
    p_approve: approve,
    p_reason: reason || null,
  });

  if (error) {
    if (/own application/i.test(error.message)) {
      return { error: 'You cannot decide your own application.' };
    }
    if (/only compliance/i.test(error.message)) {
      return { error: 'Only compliance can review applications.' };
    }
    return { error: 'Could not record the decision. Try again.' };
  }

  revalidatePath('/compliance/kyc');
  return { message: approve ? 'Approved.' : 'Rejected.' };
}
