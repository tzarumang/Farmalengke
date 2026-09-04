'use server';

import { redirect } from 'next/navigation';

import { createClient } from '@/lib/supabase/server';

import { requestOtpSchema, verifyOtpSchema } from './schema';

export interface AuthFormState {
  error?: string;
  mobileNumber?: string;
  otpSent?: boolean;
}

/**
 * A Server Action is a public HTTP endpoint: an attacker can call it with anything.
 * So every argument is validated here rather than trusted from the form.
 */
export async function requestOtp(
  _previous: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  const parsed = requestOtpSchema.safeParse({
    mobileNumber: formData.get('mobileNumber'),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? 'Check the number and try again.' };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithOtp({
    phone: parsed.data.mobileNumber,
  });

  if (error) {
    // Deliberately not echoing the provider's message: it can reveal whether a
    // number is already registered, which is an enumeration vector.
    return {
      error: 'Could not send the code. Check the number and try again.',
      mobileNumber: parsed.data.mobileNumber,
    };
  }

  return { otpSent: true, mobileNumber: parsed.data.mobileNumber };
}

export async function verifyOtp(
  _previous: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  const parsed = verifyOtpSchema.safeParse({
    mobileNumber: formData.get('mobileNumber'),
    token: formData.get('token'),
  });

  if (!parsed.success) {
    return {
      error: parsed.error.issues[0]?.message ?? 'Check the code and try again.',
      otpSent: true,
      mobileNumber: String(formData.get('mobileNumber') ?? ''),
    };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.verifyOtp({
    phone: parsed.data.mobileNumber,
    token: parsed.data.token,
    type: 'sms',
  });

  if (error) {
    return {
      error: 'That code did not match. Ask for a new one if it has expired.',
      otpSent: true,
      mobileNumber: parsed.data.mobileNumber,
    };
  }

  redirect('/profile');
}

export async function signOut(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect('/login');
}
