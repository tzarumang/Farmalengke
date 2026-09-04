'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Notice } from '@/components/ui/Notice';

import { inviteMember, type CooperativeState } from '../actions';

const initialState: CooperativeState = {};

export function InviteMember({ cooperativeId }: { cooperativeId: string }) {
  const [state, formAction, pending] = useActionState(inviteMember, initialState);

  return (
    <form action={formAction} noValidate>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      {state.message ? <Notice tone="success">{state.message}</Notice> : null}

      <input type="hidden" name="cooperativeId" value={cooperativeId} />
      <Field
        id={`invite-${cooperativeId}`}
        name="mobileNumber"
        type="tel"
        inputMode="tel"
        label="Invite by mobile number"
        hint="They have to accept before they join. You cannot add somebody without asking."
        error={state.fieldErrors?.mobileNumber}
        required
      />
      <Button type="submit" pending={pending}>
        Send invitation
      </Button>
    </form>
  );
}
