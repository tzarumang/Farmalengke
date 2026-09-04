export const KYC_TIERS = ['tier_0', 'tier_1', 'tier_2'] as const;
export type KycTier = (typeof KYC_TIERS)[number];

export const tierLabels: Record<KycTier, string> = {
  tier_0: 'Not verified',
  tier_1: 'Basic',
  tier_2: 'Full',
};

export const KYC_DOCUMENT_TYPES = [
  'portrait',
  'gov_id_front',
  'gov_id_back',
  'selfie',
] as const;
export type KycDocumentType = (typeof KYC_DOCUMENT_TYPES)[number];

export const documentLabels: Record<KycDocumentType, string> = {
  portrait: 'Photo of you',
  gov_id_front: 'Government ID, front',
  gov_id_back: 'Government ID, back',
  selfie: 'Selfie',
};

export const SUBMISSION_STATUSES = [
  'draft',
  'submitted',
  'approved',
  'rejected',
  'withdrawn',
] as const;
export type SubmissionStatus = (typeof SUBMISSION_STATUSES)[number];

export const submissionStatusLabels: Record<SubmissionStatus, string> = {
  draft: 'Not sent yet',
  submitted: 'Being checked',
  approved: 'Approved',
  rejected: 'Not accepted',
  withdrawn: 'Withdrawn',
};

export interface TierRequirement {
  tier: KycTier;
  documentType: KycDocumentType;
  description: string;
}

export interface KycDocument {
  id: string;
  documentType: KycDocumentType;
  uploadedAt: string;
}

export interface KycSubmission {
  id: string;
  subjectId: string;
  subjectName: string | null;
  requestedTier: KycTier;
  status: SubmissionStatus;
  submittedAt: string | null;
  reviewedAt: string | null;
  decisionReason: string | null;
  documents: KycDocument[];
}

/**
 * Where a document lives in the private bucket.
 *
 * Computed the same way on the client (which uploads) and the server (which
 * records the row), so the two cannot disagree. The first segment is the owner's
 * id, which is what the storage policy checks — a client cannot write outside
 * its own folder however it constructs this.
 */
export function documentStoragePath(
  userId: string,
  submissionId: string,
  documentType: KycDocumentType,
): string {
  return `${userId}/${submissionId}/${documentType}`;
}

export const MAX_DOCUMENT_BYTES = 5 * 1024 * 1024;

export const ACCEPTED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
