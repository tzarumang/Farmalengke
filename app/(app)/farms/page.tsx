import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';

import { EmptyState } from '@/components/ui/EmptyState';
import { listOwnFarms } from '@/features/farms/data';
import { formatArea } from '@/features/farms/schema';
import { getVerifiedUserId } from '@/features/profile/data';

import styles from './farms.module.css';

export const metadata: Metadata = { title: 'Your farms — Farmalengke' };

export default async function FarmsPage() {
  // The proxy redirects signed-out visitors, but it is a convenience, not a
  // security boundary — so verify here too.
  if (!(await getVerifiedUserId())) redirect('/login');

  const farms = await listOwnFarms();

  return (
    <>
      <h1>Your farms</h1>

      {farms.length === 0 ? (
        <EmptyState
          title="No farms yet"
          action={
            <Link className={styles.primaryLink} href="/farms/new">
              Add your first farm
            </Link>
          }
        >
          Add a farm so you can list produce from it. You only need the barangay —
          an exact location is optional.
        </EmptyState>
      ) : (
        <>
          <p>
            <Link className={styles.primaryLink} href="/farms/new">
              Add another farm
            </Link>
          </p>

          <ul className={styles.list}>
            {farms.map((farm) => (
              <li key={farm.id} className={styles.card}>
                <h2 className={styles.name}>{farm.name}</h2>
                <p className={styles.meta}>
                  {farm.barangay}, {farm.cityMunicipality}, {farm.province}
                </p>
                <dl className={styles.details}>
                  <div>
                    <dt>Area</dt>
                    <dd>{formatArea(farm)}</dd>
                  </div>
                  <div>
                    <dt>Exact location</dt>
                    <dd>{farm.hasSharedLocation ? 'Shared' : 'Not shared'}</dd>
                  </div>
                </dl>
              </li>
            ))}
          </ul>
        </>
      )}
    </>
  );
}
