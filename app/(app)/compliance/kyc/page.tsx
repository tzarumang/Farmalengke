import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { EmptyState } from '@/components/ui/EmptyState';
import { Notice } from '@/components/ui/Notice';
import { ReviewSubmission } from '@/features/kyc/components/ReviewSubmission';
import { listSubmissionsAwaitingReview, signDocumentUrl } from '@/features/kyc/data';
import { documentLabels, documentStoragePath, tierLabels } from '@/features/kyc/schema';
import { getVerifiedRoles, getVerifiedUserId } from '@/features/profile/data';

import styles from './review.module.css';

export const metadata: Metadata = { title: 'Verification queue — Farmalengke' };

export default async function ComplianceKycPage() {
  if (!(await getVerifiedUserId())) redirect('/login');

  const roles = await getVerifiedRoles();
  if (!roles.includes('compliance') && !roles.includes('admin')) {
    return (
      <>
        <h1>Verification queue</h1>
        <Notice tone="error">
          Only compliance can review identity documents.
        </Notice>
      </>
    );
  }

  const queue = await listSubmissionsAwaitingReview();

  if (queue.length === 0) {
    return (
      <>
        <h1>Verification queue</h1>
        <EmptyState title="Nothing waiting">
          Applications appear here once a farmer sends one.
        </EmptyState>
      </>
    );
  }

  // Signed URLs are minted per render and expire in a minute, so the page cannot
  // become a durable link to somebody's identity documents.
  const withUrls = await Promise.all(
    queue.map(async (submission) => ({
      submission,
      documents: await Promise.all(
        submission.documents.map(async (document) => ({
          ...document,
          url: await signDocumentUrl(
            documentStoragePath(submission.subjectId, submission.id, document.documentType),
          ),
        })),
      ),
    })),
  );

  return (
    <>
      <h1>Verification queue</h1>
      <p>
        {queue.length} application{queue.length === 1 ? '' : 's'} waiting. Your name
        and the time are recorded against every decision.
      </p>

      <ul className={styles.list}>
        {withUrls.map(({ submission, documents }) => (
          <li key={submission.id} className={styles.card}>
            <h2 className={styles.name}>
              {submission.subjectName ?? 'Unnamed account'}
              <span className={styles.tier}> · {tierLabels[submission.requestedTier]}</span>
            </h2>

            <p className={styles.meta}>
              Sent{' '}
              {submission.submittedAt
                ? new Date(submission.submittedAt).toLocaleString('en-PH')
                : 'recently'}
            </p>

            <ul className={styles.documents}>
              {documents.map((document) => (
                <li key={document.id}>
                  {document.url ? (
                    <a href={document.url} target="_blank" rel="noreferrer">
                      {documentLabels[document.documentType]}
                    </a>
                  ) : (
                    <span className={styles.missing}>
                      {documentLabels[document.documentType]} — could not load
                    </span>
                  )}
                </li>
              ))}
            </ul>

            <ReviewSubmission submissionId={submission.id} />
          </li>
        ))}
      </ul>
    </>
  );
}
