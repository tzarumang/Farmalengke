'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Notice } from '@/components/ui/Notice';

import { startSubmission, type KycState } from '../actions';

const initialState: KycState = {};

export function StartSubmission({ tier, label }: { tier: 'tier_1' | 'tier_2'; label: string }) {
  const [state, formAction, pending] = useActionState(startSubmission, initialState);

  return (
    <form action={formAction}>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      <input type="hidden" name="requestedTier" value={tier} />
      <Button type="submit" pending={pending}>
        {label}
      </Button>
    </form>
  );
}
