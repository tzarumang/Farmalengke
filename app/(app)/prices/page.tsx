import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { EmptyState } from '@/components/ui/EmptyState';
import { Notice } from '@/components/ui/Notice';
import { listOwnFarms } from '@/features/farms/data';
import { getPriceViews } from '@/features/pricing/data';
import { formatPeso, STALE_AFTER_HOURS } from '@/features/pricing/schema';
import { getVerifiedUserId } from '@/features/profile/data';
import { listCommodities } from '@/features/reference/data';

import styles from './prices.module.css';

export const metadata: Metadata = { title: 'Prices — Farmalengke' };

export default async function PricesPage() {
  if (!(await getVerifiedUserId())) redirect('/login');

  const farms = await listOwnFarms();
  if (farms.length === 0) {
    return (
      <>
        <h1>Prices</h1>
        <EmptyState title="Add a farm first">
          Prices differ by region, so we need to know where you grow before we can
          show you the right ones.
        </EmptyState>
      </>
    );
  }

  const regionCode = farms[0]!.regionCode;
  const commodities = await listCommodities(regionCode);
  const views = await getPriceViews(
    commodities.map((c) => c.id),
    regionCode,
  );

  const byId = new Map(commodities.map((c) => [c.id, c]));

  return (
    <>
      <h1>Prices</h1>
      <p>
        What Farmalengke is paying today in your region. Use it to decide what to
        ask for your own produce — you set your own price on a listing.
      </p>

      <ul className={styles.list}>
        {views.map((view) => {
          const commodity = byId.get(view.commodityId);
          return (
            <li key={view.commodityId} className={styles.card}>
              <h2 className={styles.name}>
                {commodity?.nameFil}
                <span className={styles.secondary}> · {commodity?.nameEn}</span>
              </h2>

              {view.current === null ? (
                // FR-6: never show a price without a source. No published figure
                // means saying so, not showing a zero.
                <p className={styles.noPrice}>
                  No price published yet for this commodity.
                </p>
              ) : (
                <>
                  <p className={styles.price}>
                    {formatPeso(view.current.pricePerKg)}
                    <span className={styles.perKg}> per kg</span>
                  </p>

                  {view.isStale ? (
                    <Notice tone="info" title="Out of date">
                      This price is more than {STALE_AFTER_HOURS} hours old. Treat it
                      as a guide, not today&rsquo;s bid.
                    </Notice>
                  ) : null}

                  {view.sevenDayLow !== null && view.sevenDayHigh !== null ? (
                    <p className={styles.range}>
                      Last 7 days: {formatPeso(view.sevenDayLow)} –{' '}
                      {formatPeso(view.sevenDayHigh)}
                    </p>
                  ) : null}

                  {/* FR-6 requires the source and timestamp of every figure. */}
                  <p className={styles.source}>
                    {view.current.source} · {new Date(view.current.observedAt).toLocaleString('en-PH')}
                  </p>
                </>
              )}
            </li>
          );
        })}
      </ul>
    </>
  );
}
