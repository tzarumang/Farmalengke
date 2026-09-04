import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { FarmForm } from '@/features/farms/components/FarmForm';
import { getVerifiedUserId } from '@/features/profile/data';
import { listRegions } from '@/features/reference/data';

export const metadata: Metadata = { title: 'Add a farm — Farmalengke' };

export default async function NewFarmPage() {
  if (!(await getVerifiedUserId())) redirect('/login');

  const regions = await listRegions();

  return (
    <>
      <h1>Add a farm</h1>
      <p>
        Tell us where you grow. We only need the barangay — you can add an exact
        location later if you want to.
      </p>
      <FarmForm regions={regions} />
    </>
  );
}
