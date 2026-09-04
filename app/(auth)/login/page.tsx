import type { Metadata } from 'next';

import { LoginForm } from './LoginForm';

export const metadata: Metadata = { title: 'Sign in — Farmalengke' };

export default function LoginPage() {
  return (
    <>
      <h1>Farmalengke</h1>
      <p>
        Enter your mobile number and we will text you a 6-digit code. You do not need an
        email address.
      </p>
      <LoginForm />
    </>
  );
}
