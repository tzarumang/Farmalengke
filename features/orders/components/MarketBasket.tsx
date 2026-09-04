'use client';

import { useActionState, useMemo, useState } from 'react';

import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Notice } from '@/components/ui/Notice';
import type { MarketListing } from '@/features/marketplace/types';
import { formatPeso } from '@/features/pricing/schema';

import { placeOrder, type PlaceOrderState } from '../actions';

import styles from './MarketBasket.module.css';

const initialState: PlaceOrderState = {};

/**
 * Browse results with selection, and the order form beneath.
 *
 * Selection is whole-listing: FR-8 aggregates listings to reach a volume rather
 * than splitting one, and the reservation in the database is whole-listing to
 * match. A farmer who wants to sell in parts lists in parts.
 */
export function MarketBasket({ listings }: { listings: MarketListing[] }) {
  const [state, formAction, pending] = useActionState(placeOrder, initialState);
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const chosen = useMemo(
    () => listings.filter((l) => selected.has(l.id)),
    [listings, selected],
  );

  const totalKg = chosen.reduce((sum, l) => sum + l.quantityKg, 0);
  const totalPrice = chosen.reduce((sum, l) => sum + l.lineTotal, 0);

  function toggle(id: string) {
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  return (
    <form action={formAction} noValidate>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      {state.orderId ? (
        <Notice tone="success">
          Order placed. Each farmer now has to confirm their part.
        </Notice>
      ) : null}

      <ul className={styles.list}>
        {listings.map((listing) => {
          const isSelected = selected.has(listing.id);
          return (
            <li key={listing.id} className={styles.card} data-selected={isSelected}>
              <label className={styles.row} htmlFor={`listing-${listing.id}`}>
                <input
                  id={`listing-${listing.id}`}
                  type="checkbox"
                  className={styles.checkbox}
                  checked={isSelected}
                  onChange={() => toggle(listing.id)}
                />
                <span className={styles.body}>
                  <span className={styles.name}>
                    {listing.commodityNameFil}
                    <span className={styles.secondary}> · {listing.commodityNameEn}</span>
                    {listing.variety ? <span className={styles.secondary}> · {listing.variety}</span> : null}
                  </span>

                  <span className={styles.qty}>
                    {listing.quantity} {listing.unitCode}
                    {listing.unitCode !== 'kg' ? ` (${listing.quantityKg} kg)` : ''}
                  </span>

                  <span className={styles.price}>
                    {formatPeso(listing.askingPricePerKg)}/kg ·{' '}
                    <strong>{formatPeso(listing.lineTotal)}</strong> total
                  </span>

                  <span className={styles.meta}>
                    {listing.barangay}, {listing.cityMunicipality}, {listing.province}
                    {' · '}
                    {listing.availability === 'expected' && listing.availableFrom
                      ? `ready ${listing.availableFrom}`
                      : 'ready now'}
                    {listing.claimedGrade ? ` · ${listing.claimedGrade} (claimed)` : ''}
                  </span>
                </span>
              </label>
              {isSelected ? <input type="hidden" name="listingIds" value={listing.id} /> : null}
            </li>
          );
        })}
      </ul>

      {chosen.length > 0 ? (
        <div className={styles.basket}>
          <h2>Your order</h2>
          <p className={styles.total}>
            {chosen.length} listing{chosen.length === 1 ? '' : 's'} · {totalKg} kg ·{' '}
            <strong>{formatPeso(totalPrice)}</strong>
          </p>

          <Notice tone="info" title="Before you order">
            Placing this reserves every listing straight away. Each farmer then has
            a limited time to confirm; anything unanswered goes back on the market.
          </Notice>

          <Field
            id="deliveryDate"
            name="deliveryDate"
            label="Delivery date"
            type="date"
            error={state.fieldErrors?.deliveryDate}
            required
          />
          <Field
            id="deliveryBarangay"
            name="deliveryBarangay"
            label="Delivery barangay"
            error={state.fieldErrors?.deliveryBarangay}
            required
          />
          <Field
            id="deliveryCity"
            name="deliveryCity"
            label="Delivery city or municipality"
            error={state.fieldErrors?.deliveryCity}
            required
          />
          <Field
            id="deliveryProvince"
            name="deliveryProvince"
            label="Delivery province"
            error={state.fieldErrors?.deliveryProvince}
            required
          />

          <Button type="submit" pending={pending}>
            Place order for {formatPeso(totalPrice)}
          </Button>
        </div>
      ) : null}
    </form>
  );
}
