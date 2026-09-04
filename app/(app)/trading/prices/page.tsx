import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { Notice } from '@/components/ui/Notice';
import { PublishPriceForm } from '@/features/pricing/components/PublishPriceForm';
import { listPublishedPrices } from '@/features/pricing/data';
import { formatPeso } from '@/features/pricing/schema';
import { getVerifiedRoles, getVerifiedUserId } from '@/features/profile/data';
import { listCommodities, listRegions } from '@/features/reference/data';

import styles from './trading-prices.module.css';

export const metadata: Metadata = { title: 'Publish prices — Farmalengke' };

export default async function TradingPricesPage() {
  if (!(await getVerifiedUserId())) redirect('/login');

  // Row-level security would refuse the write anyway; checking here means the
  // wrong role sees an honest message instead of a form that cannot succeed.
  const roles = await getVerifiedRoles();
  if (!roles.includes('trading_desk') && !roles.includes('admin')) {
    return (
      <>
        <h1>Publish prices</h1>
        <Notice tone="error">
          Only the trading desk can publish prices.
        </Notice>
      </>
    );
  }

  const [commodities, regions, published] = await Promise.all([
    listCommodities(),
    listRegions(),
    listPublishedPrices(),
  ]);

  return (
    <>
      <h1>Publish prices</h1>
      <p>
        Published prices are history: they cannot be edited or deleted, and every
        one records who published it. To change a price, publish a new one.
      </p>

      <PublishPriceForm commodities={commodities} regions={regions} />

      <h2>Recent</h2>
      {published.length === 0 ? (
        <p>Nothing published yet.</p>
      ) : (
        <div className={styles.tableWrap}>
          <table className={styles.table}>
            <caption className="sr-only">Recently published platform prices</caption>
            <thead>
              <tr>
                <th scope="col">Commodity</th>
                <th scope="col">Region</th>
                <th scope="col">Price / kg</th>
                <th scope="col">Effective</th>
              </tr>
            </thead>
            <tbody>
              {published.map((price) => (
                <tr key={price.id}>
                  <td>
                    {price.commodityName}
                    {price.grade ? ` (${price.grade})` : ''}
                  </td>
                  <td>{price.regionCode}</td>
                  <td>{formatPeso(price.pricePerKg)}</td>
                  <td>
                    {new Date(price.effectiveFrom).toLocaleString('en-PH')}
                    {price.isScheduled ? <span className={styles.scheduled}> scheduled</span> : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
