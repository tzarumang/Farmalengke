'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Notice } from '@/components/ui/Notice';
import { requestOtp, verifyOtp, type AuthFormState } from '@/features/auth/actions';

const initialState: AuthFormState = {};

/**
 * Two steps in one component because they are one task to the user: prove this is
 * your number. Splitting them across routes would lose the entered number on a slow
 * connection, which is exactly the connection our users are on.
 */
export function LoginForm() {
  const [requestState, requestAction, requestPending] = useActionState(
    requestOtp,
    initialState,
  );
  const [verifyState, verifyAction, verifyPending] = useActionState(
    verifyOtp,
    initialState,
  );

  const otpSent = requestState.otpSent || verifyState.otpSent;
  const mobileNumber = verifyState.mobileNumber ?? requestState.mobileNumber ?? '';
  const error = verifyState.error ?? requestState.error;

  if (!otpSent) {
    return (
      <form action={requestAction} noValidate>
        {error ? <Notice tone="error">{error}</Notice> : null}
        <Field
          id="mobileNumber"
          name="mobileNumber"
          type="tel"
          inputMode="tel"
          autoComplete="tel"
          label="Mobile number"
          hint="For example 0917 123 4567"
          defaultValue={mobileNumber}
          required
        />
        <Button type="submit" pending={requestPending}>
          Send me a code
        </Button>
      </form>
    );
  }

  return (
    <form action={verifyAction} noValidate>
      {error ? <Notice tone="error">{error}</Notice> : null}
      <Notice tone="info">
        We sent a code to <strong>{mobileNumber}</strong>.
      </Notice>

      <input type="hidden" name="mobileNumber" value={mobileNumber} />
      <Field
        id="token"
        name="token"
        type="text"
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={6}
        label="6-digit code"
        required
      />
      <Button type="submit" pending={verifyPending}>
        Sign in
      </Button>
    </form>
  );
}
