import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';

import { EmptyState } from '@/components/ui/EmptyState';
import { listOwnFarms } from '@/features/farms/data';
import { listOwnListings } from '@/features/listings/data';
import { availabilityLabels, statusLabels } from '@/features/listings/schema';
import { getVerifiedUserId } from '@/features/profile/data';

import styles from './listings.module.css';

export const metadata: Metadata = { title: 'Your produce — Farmalengke' };

export default async function ListingsPage() {
  if (!(await getVerifiedUserId())) redirect('/login');

  const [listings, farms] = await Promise.all([listOwnListings(), listOwnFarms()]);

  // A listing needs a farm, so send the farmer there first rather than showing a
  // form whose first field cannot be filled in.
  if (farms.length === 0) {
    return (
      <>
        <h1>Your produce</h1>
        <EmptyState
          title="Add a farm first"
          action={
            <Link className={styles.primaryLink} href="/farms/new">
              Add a farm
            </Link>
          }
        >
          Produce is listed from a farm, so we need to know where you grow before
          you can offer anything.
        </EmptyState>
      </>
    );
  }

  return (
    <>
      <h1>Your produce</h1>

      {listings.length === 0 ? (
        <EmptyState
          title="Nothing listed yet"
          action={
            <Link className={styles.primaryLink} href="/listings/new">
              List produce
            </Link>
          }
        >
          List what you have or expect to harvest. You can save it as a draft first
          and offer it to buyers when you are ready.
        </EmptyState>
      ) : (
        <>
          <p>
            <Link className={styles.primaryLink} href="/listings/new">
              List more produce
            </Link>
          </p>

          <ul className={styles.list}>
            {listings.map((listing) => (
              <li key={listing.id} className={styles.card}>
                <div className={styles.head}>
                  <h2 className={styles.name}>
                    {listing.commodityNameFil}
                    <span className={styles.secondaryName}> · {listing.commodityNameEn}</span>
                  </h2>
                  <span className={styles.status} data-status={listing.status}>
                    {statusLabels[listing.status]}
                  </span>
                </div>

                <p className={styles.quantity}>
                  {listing.quantity} {listing.unitCode}
                  {listing.unitCode !== 'kg' ? (
                    <span className={styles.kg}> ({listing.quantityKg} kg)</span>
                  ) : null}
                </p>

                <dl className={styles.details}>
                  <div>
                    <dt>Farm</dt>
                    <dd>{listing.farmName}</dd>
                  </div>
                  <div>
                    <dt>Ready</dt>
                    <dd>
                      {listing.availability === 'expected' && listing.availableFrom
                        ? listing.availableFrom
                        : availabilityLabels[listing.availability]}
                    </dd>
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
