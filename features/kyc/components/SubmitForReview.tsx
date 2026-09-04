'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Notice } from '@/components/ui/Notice';

import { sendForReview, type KycState } from '../actions';

const initialState: KycState = {};

export function SubmitForReview({ submissionId }: { submissionId: string }) {
  const [state, formAction, pending] = useActionState(sendForReview, initialState);

  return (
    <form action={formAction}>
      {/* "still needed: ..." comes straight from the database and lists exactly
          what is missing, which is what FR-2 requires the person to be told. */}
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      {state.message ? <Notice tone="success">{state.message}</Notice> : null}

      <input type="hidden" name="submissionId" value={submissionId} />
      <Button type="submit" pending={pending}>
        Send for checking
      </Button>
    </form>
  );
}
