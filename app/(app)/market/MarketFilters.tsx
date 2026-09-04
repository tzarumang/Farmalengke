'use client';

import type { Route } from 'next';
import { useRouter, useSearchParams } from 'next/navigation';

import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import type { Commodity, Region } from '@/features/reference/types';

import styles from './market-filters.module.css';

/**
 * FR-7 filters, kept in the URL so a buyer can bookmark or share a search and
 * the server component can render the results directly.
 */
export function MarketFilters({
  commodities,
  regions,
}: {
  commodities: Commodity[];
  regions: Region[];
}) {
  const router = useRouter();
  const params = useSearchParams();

  function apply(formData: FormData) {
    const next = new URLSearchParams();
    for (const key of ['commodityId', 'regionCode', 'minQuantityKg', 'availableBy']) {
      const value = String(formData.get(key) ?? '').trim();
      if (value) next.set(key, value);
    }
    // typedRoutes cannot verify a query string built at runtime. The pathname is
    // still checked; only the search part needs the assertion.
    router.push(`/market?${next.toString()}` as Route);
  }

  return (
    <form action={apply} className={styles.filters}>
      <Select
        id="commodityId"
        name="commodityId"
        label="Commodity"
        placeholder="Any"
        defaultValue={params.get('commodityId') ?? ''}
        options={commodities.map((c) => ({ value: c.id, label: c.nameEn }))}
      />
      <Select
        id="regionCode"
        name="regionCode"
        label="Region"
        placeholder="Any"
        defaultValue={params.get('regionCode') ?? ''}
        options={regions.map((r) => ({ value: r.code, label: r.name }))}
      />

      <div className={styles.field}>
        <label htmlFor="minQuantityKg" className={styles.label}>
          Minimum kg
        </label>
        <input
          id="minQuantityKg"
          name="minQuantityKg"
          type="text"
          inputMode="decimal"
          className={styles.input}
          defaultValue={params.get('minQuantityKg') ?? ''}
        />
      </div>

      <div className={styles.field}>
        <label htmlFor="availableBy" className={styles.label}>
          Ready by
        </label>
        <input
          id="availableBy"
          name="availableBy"
          type="date"
          className={styles.input}
          defaultValue={params.get('availableBy') ?? ''}
        />
      </div>

      <div className={styles.actions}>
        <Button type="submit" variant="secondary">
          Apply filters
        </Button>
      </div>
    </form>
  );
}
