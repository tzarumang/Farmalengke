'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Notice } from '@/components/ui/Notice';
import { Select } from '@/components/ui/Select';
import type { Commodity, Region } from '@/features/reference/types';

import { publishPrice, type PublishPriceState } from '../actions';

const initialState: PublishPriceState = {};

export function PublishPriceForm({
  commodities,
  regions,
}: {
  commodities: Commodity[];
  regions: Region[];
}) {
  const [state, formAction, pending] = useActionState(publishPrice, initialState);

  return (
    <form action={formAction} noValidate>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      {state.published ? (
        <Notice tone="success">
          Price published. It cannot be edited — publish a new one to change it.
        </Notice>
      ) : null}

      <Select
        id="commodityId"
        name="commodityId"
        label="Commodity"
        placeholder="Choose a commodity"
        options={commodities.map((c) => ({ value: c.id, label: `${c.nameEn} · ${c.nameFil}` }))}
        error={state.fieldErrors?.commodityId}
        required
      />

      <Select
        id="regionCode"
        name="regionCode"
        label="Region"
        placeholder="Choose a region"
        options={regions.map((r) => ({ value: r.code, label: r.name }))}
        error={state.fieldErrors?.regionCode}
        required
      />

      <Field
        id="grade"
        name="grade"
        label="Grade (optional)"
        hint="Leave blank to price every grade the same. A grading standard is not agreed yet."
        error={state.fieldErrors?.grade}
      />

      <Field
        id="pricePerKg"
        name="pricePerKg"
        label="Price per kilogram (PHP)"
        type="text"
        inputMode="decimal"
        error={state.fieldErrors?.pricePerKg}
        required
      />

      <Field
        id="effectiveFrom"
        name="effectiveFrom"
        label="Effective from (optional)"
        type="datetime-local"
        hint="Leave blank to take effect now. A future time schedules it; farmers will not see it until then."
        error={state.fieldErrors?.effectiveFrom}
      />

      <Button type="submit" pending={pending}>
        Publish price
      </Button>
    </form>
  );
}
