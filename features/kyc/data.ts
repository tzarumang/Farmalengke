import 'server-only';

import { getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import type { KycSubmission, KycTier, TierRequirement } from './schema';

interface SubmissionRow {
  id: string;
  subject_id: string;
  requested_tier: KycTier;
  status: KycSubmission['status'];
  submitted_at: string | null;
  reviewed_at: string | null;
  decision_reason: string | null;
  kyc_documents: { id: string; document_type: KycSubmission['documents'][number]['documentType']; uploaded_at: string }[] | null;
  profiles: { display_name: string | null } | { display_name: string | null }[] | null;
}

function one<T>(value: T | T[] | null | undefined): T | null {
  if (!value) return null;
  return Array.isArray(value) ? (value[0] ?? null) : value;
}

const SUBMISSION_COLUMNS = `
  id, subject_id, requested_tier, status, submitted_at, reviewed_at, decision_reason,
  kyc_documents(id, document_type, uploaded_at),
  profiles(display_name)
`;

function toSubmission(row: SubmissionRow): KycSubmission {
  return {
    id: row.id,
    subjectId: row.subject_id,
    subjectName: one(row.profiles)?.display_name ?? null,
    requestedTier: row.requested_tier,
    status: row.status,
    submittedAt: row.submitted_at,
    reviewedAt: row.reviewed_at,
    decisionReason: row.decision_reason,
    documents: (row.kyc_documents ?? []).map((d) => ({
      id: d.id,
      documentType: d.document_type,
      uploadedAt: d.uploaded_at,
    })),
  };
}

export async function listTierRequirements(): Promise<TierRequirement[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('kyc_tier_requirements')
    .select('tier, document_type, description');

  if (error || !data) return [];
  return (data as unknown as { tier: KycTier; document_type: TierRequirement['documentType']; description: string }[]).map(
    (r) => ({ tier: r.tier, documentType: r.document_type, description: r.description }),
  );
}

export async function listOwnSubmissions(): Promise<KycSubmission[]> {
  const userId = await getVerifiedUserId();
  if (!userId) return [];

  const supabase = await createClient();
  const { data, error } = await supabase
    .from('kyc_submissions')
    .select(SUBMISSION_COLUMNS)
    .eq('subject_id', userId)
    .order('created_at', { ascending: false });

  if (error || !data) return [];
  return (data as unknown as SubmissionRow[]).map(toSubmission);
}

/** The review queue. Row-level security limits this to compliance and admin. */
export async function listSubmissionsAwaitingReview(): Promise<KycSubmission[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('kyc_submissions')
    .select(SUBMISSION_COLUMNS)
    .eq('status', 'submitted')
    .order('submitted_at', { ascending: true });

  if (error || !data) return [];
  return (data as unknown as SubmissionRow[]).map(toSubmission);
}

/**
 * A short-lived link to view one document.
 *
 * The bucket is private, so an image is only ever reachable through a signed URL
 * minted for a caller the policies already admit. Sixty seconds is enough to
 * render the page and short enough that a leaked link is worthless.
 */
export async function signDocumentUrl(storagePath: string): Promise<string | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.storage
    .from('kyc-documents')
    .createSignedUrl(storagePath, 60);

  if (error || !data) return null;
  return data.signedUrl;
}
