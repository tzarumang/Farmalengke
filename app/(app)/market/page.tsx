import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { EmptyState } from '@/components/ui/EmptyState';
import { Notice } from '@/components/ui/Notice';
import { browseListings } from '@/features/marketplace/data';
import { MarketBasket } from '@/features/orders/components/MarketBasket';
import { getVerifiedRoles, getVerifiedUserId } from '@/features/profile/data';
import { listCommodities, listRegions } from '@/features/reference/data';

import { MarketFilters } from './MarketFilters';

export const metadata: Metadata = { title: 'Market — Farmalengke' };

export default async function MarketPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  if (!(await getVerifiedUserId())) redirect('/login');

  const roles = await getVerifiedRoles();
  const canBuy =
    roles.includes('buyer') || roles.includes('trading_desk') || roles.includes('admin');

  if (!canBuy) {
    return (
      <>
        <h1>Market</h1>
        <Notice tone="info">
          The market is for buyers. If you sell produce, your listings are under
          Produce.
        </Notice>
      </>
    );
  }

  const params = await searchParams;
  const asString = (v: string | string[] | undefined) =>
    typeof v === 'string' && v.length > 0 ? v : undefined;

  const [commodities, regions] = await Promise.all([listCommodities(), listRegions()]);

  const minQuantity = asString(params.minQuantityKg);
  const listings = await browseListings({
    commodityId: asString(params.commodityId),
    regionCode: asString(params.regionCode),
    minQuantityKg: minQuantity ? Number(minQuantity) : undefined,
    availableBy: asString(params.availableBy),
  });

  return (
    <>
      <h1>Market</h1>
      <p>Produce offered by farmers. Prices are set by the farmer selling it.</p>

      <MarketFilters commodities={commodities} regions={regions} />

      {listings.length === 0 ? (
        <EmptyState title="Nothing matches">
          No produce matches those filters right now. Try widening them, or check
          back — listings appear as farmers offer them.
        </EmptyState>
      ) : (
        <MarketBasket listings={listings} />
      )}
    </>
  );
}
