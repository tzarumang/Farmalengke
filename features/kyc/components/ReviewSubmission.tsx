'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Notice } from '@/components/ui/Notice';

import { reviewSubmission, type KycState } from '../actions';

import styles from './ReviewSubmission.module.css';

const initialState: KycState = {};

/**
 * A compliance decision on one application.
 *
 * The reason field is always present rather than appearing only on rejection:
 * the database refuses a rejection without one, and revealing that requirement
 * only after a failed click wastes a reviewer's time.
 */
export function ReviewSubmission({ submissionId }: { submissionId: string }) {
  const [state, formAction, pending] = useActionState(reviewSubmission, initialState);

  return (
    <form action={formAction} className={styles.form}>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      {state.message ? <Notice tone="success">{state.message}</Notice> : null}

      <input type="hidden" name="submissionId" value={submissionId} />

      <label className={styles.label} htmlFor={`reason-${submissionId}`}>
        Reason <span className={styles.hint}>(required to reject)</span>
      </label>
      <textarea
        id={`reason-${submissionId}`}
        name="reason"
        rows={2}
        className={styles.textarea}
        placeholder="What did you check, or what was wrong?"
      />

      <div className={styles.actions}>
        <Button type="submit" name="decision" value="approve" pending={pending}>
          Approve
        </Button>
        <Button type="submit" name="decision" value="reject" variant="secondary" pending={pending}>
          Reject
        </Button>
      </div>
    </form>
  );
}
