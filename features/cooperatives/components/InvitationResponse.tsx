'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Notice } from '@/components/ui/Notice';

import { respondToInvitation, type CooperativeState } from '../actions';

import styles from './InvitationResponse.module.css';

const initialState: CooperativeState = {};

/** Join or decline. Equal weight, as with an order: it is the farmer's choice. */
export function InvitationResponse({
  membershipId,
  cooperativeName,
}: {
  membershipId: string;
  cooperativeName: string;
}) {
  const [state, formAction, pending] = useActionState(respondToInvitation, initialState);

  if (state.message) return <Notice tone="success">{state.message}</Notice>;

  return (
    <form action={formAction}>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      <input type="hidden" name="membershipId" value={membershipId} />

      <p className={styles.prompt}>
        <strong>{cooperativeName}</strong> has invited you to sell together.
      </p>

      <div className={styles.actions}>
        <Button type="submit" name="decision" value="accept" pending={pending}>
          Join
        </Button>
        <Button type="submit" name="decision" value="decline" variant="secondary" pending={pending}>
          No thanks
        </Button>
      </div>
    </form>
  );
}
