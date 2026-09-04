'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Notice } from '@/components/ui/Notice';

import { leaveCooperative, type CooperativeState } from '../actions';

const initialState: CooperativeState = {};

export function LeaveCooperative({ membershipId }: { membershipId: string }) {
  const [state, formAction, pending] = useActionState(leaveCooperative, initialState);

  if (state.message) return <Notice tone="info">{state.message}</Notice>;

  return (
    <form action={formAction}>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      <input type="hidden" name="membershipId" value={membershipId} />
      <Button type="submit" variant="secondary" pending={pending}>
        Leave this group
      </Button>
    </form>
  );
}
