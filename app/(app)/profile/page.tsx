import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { Notice } from '@/components/ui/Notice';
import { signOut } from '@/features/auth/actions';
import { ProfileForm } from '@/features/profile/components/ProfileForm';
import { getOwnProfile, getVerifiedUserId } from '@/features/profile/data';

export const metadata: Metadata = { title: 'Your profile — Farmalengke' };

const kycMessage: Record<string, string> = {
  tier_0: 'Your account is not verified yet. You can set up your details now.',
  tier_1: 'Your account is verified for basic transactions.',
  tier_2: 'Your account is fully verified.',
};

export default async function ProfilePage() {
  // The proxy already redirected signed-out visitors, but it is a UX optimisation,
  // not a security boundary — so the page verifies identity itself.
  const userId = await getVerifiedUserId();
  if (!userId) redirect('/login');

  const profile = await getOwnProfile();

  // Empty state: authenticated, but the profile row does not exist yet.
  if (!profile) {
    return (
      <>
        <h1>Finish setting up</h1>
        <Notice tone="info">
          We could not load your details yet. Refresh the page, or sign in again if this
          keeps happening.
        </Notice>
        <form action={signOut}>
          <button type="submit">Sign out</button>
        </form>
      </>
    );
  }

  return (
    <>
      <h1>Your profile</h1>

      <Notice tone="info" title="Account">
        <p style={{ margin: 0 }}>
          {profile.mobileNumber}
          {profile.roles.length > 0 ? ` · ${profile.roles.join(', ')}` : ''}
        </p>
        <p style={{ margin: 0 }}>{kycMessage[profile.kycTier]}</p>
      </Notice>

      <ProfileForm profile={profile} />

      <form action={signOut}>
        <button type="submit">Sign out</button>
      </form>
    </>
  );
}
