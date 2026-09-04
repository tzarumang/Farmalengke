'use client';

import { useActionState, useMemo, useState } from 'react';

import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Notice } from '@/components/ui/Notice';
import { Select } from '@/components/ui/Select';

import { createListing, type ListingFormState } from '../actions';
import { LISTING_AVAILABILITY, availabilityLabels } from '../schema';

import styles from './ListingForm.module.css';

const initialState: ListingFormState = {};

export interface ListingFormFarm {
  id: string;
  name: string;
  regionCode: string;
}

export interface ListingFormCommodity {
  id: string;
  nameEn: string;
  nameFil: string;
  regionCodes: string[];
  unitCodes: string[];
}

export interface ListingFormUnit {
  code: string;
  nameEn: string;
  nameFil: string;
}

export function ListingForm({
  farms,
  commodities,
  units,
}: {
  farms: ListingFormFarm[];
  commodities: ListingFormCommodity[];
  units: ListingFormUnit[];
}) {
  const [state, formAction, pending] = useActionState(createListing, initialState);

  const [farmId, setFarmId] = useState(farms[0]?.id ?? '');
  const [commodityId, setCommodityId] = useState('');
  const [availability, setAvailability] =
    useState<(typeof LISTING_AVAILABILITY)[number]>('available_now');

  const selectedFarm = farms.find((f) => f.id === farmId);

  // Only offer what the chosen farm's region actually trades. A farmer can still
  // be growing something unusual, but the common case should not require scrolling
  // past nine commodities to find the four that are local.
  const availableCommodities = useMemo(() => {
    if (!selectedFarm) return commodities;
    const local = commodities.filter((c) => c.regionCodes.includes(selectedFarm.regionCode));
    return local.length > 0 ? local : commodities;
  }, [commodities, selectedFarm]);

  // Only units with a recorded kilogram conversion. Offering one without would
  // produce a write the database correctly refuses.
  const availableUnits = useMemo(() => {
    const commodity = commodities.find((c) => c.id === commodityId);
    if (!commodity) return units;
    return units.filter((u) => commodity.unitCodes.includes(u.code));
  }, [commodities, commodityId, units]);

  return (
    <form action={formAction} noValidate>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}

      <Select
        id="farmId"
        name="farmId"
        label="Which farm?"
        options={farms.map((f) => ({ value: f.id, label: f.name }))}
        value={farmId}
        onChange={(event) => setFarmId(event.target.value)}
        error={state.fieldErrors?.farmId}
        required
      />

      <Select
        id="commodityId"
        name="commodityId"
        label="What are you selling?"
        placeholder="Choose produce"
        options={availableCommodities.map((c) => ({
          value: c.id,
          label: `${c.nameFil} · ${c.nameEn}`,
        }))}
        value={commodityId}
        onChange={(event) => setCommodityId(event.target.value)}
        error={state.fieldErrors?.commodityId}
        required
      />

      <Field
        id="variety"
        name="variety"
        label="Variety (optional)"
        error={state.fieldErrors?.variety}
      />

      <div className={styles.row}>
        <Field
          id="quantity"
          name="quantity"
          label="How much?"
          type="text"
          inputMode="decimal"
          error={state.fieldErrors?.quantity}
          required
        />
        <Select
          id="unitCode"
          name="unitCode"
          label="Unit"
          options={availableUnits.map((u) => ({
            value: u.code,
            label: `${u.nameFil} · ${u.nameEn}`,
          }))}
          error={state.fieldErrors?.unitCode}
          required
        />
      </div>

      <Field
        id="askingPrice"
        name="askingPrice"
        label="Your price"
        type="text"
        inputMode="decimal"
        hint="Pesos per unit you are selling in. Check the price page to see what the platform is paying."
        error={state.fieldErrors?.askingPrice}
      />

      <Field
        id="claimedGrade"
        name="claimedGrade"
        label="Quality (optional)"
        hint="Your own description. The bagsakan grades it again on arrival."
        error={state.fieldErrors?.claimedGrade}
      />

      <Select
        id="availability"
        name="availability"
        label="When is it ready?"
        options={LISTING_AVAILABILITY.map((a) => ({
          value: a,
          label: availabilityLabels[a],
        }))}
        value={availability}
        onChange={(event) =>
          setAvailability(event.target.value as (typeof LISTING_AVAILABILITY)[number])
        }
        error={state.fieldErrors?.availability}
        required
      />

      {availability === 'expected' ? (
        <Field
          id="availableFrom"
          name="availableFrom"
          label="Ready from"
          type="date"
          error={state.fieldErrors?.availableFrom}
          required
        />
      ) : null}

      <label className={styles.checkbox} htmlFor="publish">
        <input id="publish" name="publish" type="checkbox" />
        <span>
          Offer this to buyers now. Leave unticked to save it as a draft only you
          can see.
        </span>
      </label>

      <Button type="submit" pending={pending}>
        Save listing
      </Button>
    </form>
  );
}
