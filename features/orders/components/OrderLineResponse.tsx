'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Notice } from '@/components/ui/Notice';

import { respondToOrderLine, type RespondState } from '../actions';

import styles from './OrderLineResponse.module.css';

const initialState: RespondState = {};

/**
 * Confirm or decline one line of an order.
 *
 * Both choices are plain buttons of equal weight. Nudging a farmer toward
 * accepting with a big green button and a grey link would be a dark pattern in a
 * decision about their own income.
 */
export function OrderLineResponse({ lineId, total }: { lineId: string; total: string }) {
  const [state, formAction, pending] = useActionState(respondToOrderLine, initialState);

  if (state.done) {
    return <Notice tone="success">Your answer is recorded.</Notice>;
  }

  return (
    <form action={formAction}>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      <input type="hidden" name="lineId" value={lineId} />

      <div className={styles.actions}>
        <Button type="submit" name="decision" value="confirm" pending={pending}>
          Accept {total}
        </Button>
        <Button type="submit" name="decision" value="decline" variant="secondary" pending={pending}>
          Decline
        </Button>
      </div>
    </form>
  );
}
