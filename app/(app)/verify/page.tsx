import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { Notice } from '@/components/ui/Notice';
import { DocumentUpload } from '@/features/kyc/components/DocumentUpload';
import { StartSubmission } from '@/features/kyc/components/StartSubmission';
import { SubmitForReview } from '@/features/kyc/components/SubmitForReview';
import { listOwnSubmissions, listTierRequirements } from '@/features/kyc/data';
import { submissionStatusLabels, tierLabels, type KycTier } from '@/features/kyc/schema';
import { getOwnProfile, getVerifiedUserId } from '@/features/profile/data';

import styles from './verify.module.css';

export const metadata: Metadata = { title: 'Verification — Farmalengke' };

const tierExplanation: Record<KycTier, string> = {
  tier_0:
    'Your account is not verified yet, so it cannot be used to trade. Send a photo of yourself to get started.',
  tier_1:
    'You can trade up to the basic limit. Send a government ID and a selfie to raise it.',
  tier_2: 'You are fully verified.',
};

export default async function VerifyPage() {
  const userId = await getVerifiedUserId();
  if (!userId) redirect('/login');

  const [profile, requirements, submissions] = await Promise.all([
    getOwnProfile(),
    listTierRequirements(),
    listOwnSubmissions(),
  ]);

  if (!profile) redirect('/profile');

  const currentTier = profile.kycTier;
  const nextTier: KycTier | null =
    currentTier === 'tier_0' ? 'tier_1' : currentTier === 'tier_1' ? 'tier_2' : null;

  const openSubmission = submissions.find(
    (s) => s.status === 'draft' || s.status === 'submitted',
  );
  const lastRejection = submissions.find((s) => s.status === 'rejected');

  return (
    <>
      <h1>Verification</h1>

      <Notice tone={currentTier === 'tier_0' ? 'info' : 'success'} title={tierLabels[currentTier]}>
        {tierExplanation[currentTier]}
      </Notice>

      {lastRejection?.decisionReason && !openSubmission ? (
        <Notice tone="error" title="Last time">
          {lastRejection.decisionReason}
        </Notice>
      ) : null}

      {openSubmission?.status === 'submitted' ? (
        <p>
          Your application is being checked. We will let you know when it is done.
        </p>
      ) : null}

      {openSubmission?.status === 'draft' ? (
        <>
          <h2>Send these</h2>
          <p>
            Photos stay private. Only the people who check identity documents can
            see them.
          </p>

          {requirements
            .filter((r) => r.tier === openSubmission.requestedTier)
            .map((requirement) => (
              <DocumentUpload
                key={requirement.documentType}
                userId={userId}
                submissionId={openSubmission.id}
                documentType={requirement.documentType}
                description={requirement.description}
                alreadyUploaded={openSubmission.documents.some(
                  (d) => d.documentType === requirement.documentType,
                )}
              />
            ))}

          <SubmitForReview submissionId={openSubmission.id} />
        </>
      ) : null}

      {!openSubmission && nextTier ? (
        <>
          <h2>{nextTier === 'tier_1' ? 'Get started' : 'Raise your limit'}</h2>
          <ul className={styles.requirements}>
            {requirements
              .filter((r) => r.tier === nextTier)
              .map((r) => (
                <li key={r.documentType}>{r.description}</li>
              ))}
          </ul>
          <StartSubmission
            tier={nextTier}
            label={nextTier === 'tier_1' ? 'Start verification' : 'Raise my limit'}
          />
        </>
      ) : null}

      {submissions.length > 0 ? (
        <>
          <h2>History</h2>
          <ul className={styles.history}>
            {submissions.map((s) => (
              <li key={s.id}>
                {tierLabels[s.requestedTier]} · {submissionStatusLabels[s.status]}
                {s.reviewedAt ? ` · ${new Date(s.reviewedAt).toLocaleDateString('en-PH')}` : ''}
              </li>
            ))}
          </ul>
        </>
      ) : null}
    </>
  );
}
