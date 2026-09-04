'use client';

import { useActionState, useState } from 'react';

import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Notice } from '@/components/ui/Notice';
import { Select } from '@/components/ui/Select';
import type { Region } from '@/features/reference/types';

import { createFarm, type FarmFormState } from '../actions';
import { AREA_UNITS, areaUnitLabels } from '../schema';

import styles from './FarmForm.module.css';

const initialState: FarmFormState = {};

export function FarmForm({ regions }: { regions: Region[] }) {
  const [state, formAction, pending] = useActionState(createFarm, initialState);
  const [shareLocation, setShareLocation] = useState(false);

  return (
    <form action={formAction} noValidate>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}

      <Field
        id="name"
        name="name"
        label="Farm name"
        hint="Whatever you call it — “Upper field”, “Lola's lot”."
        error={state.fieldErrors?.name}
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
        id="barangay"
        name="barangay"
        label="Barangay"
        error={state.fieldErrors?.barangay}
        required
      />
      <Field
        id="cityMunicipality"
        name="cityMunicipality"
        label="City or municipality"
        error={state.fieldErrors?.cityMunicipality}
        required
      />
      <Field
        id="province"
        name="province"
        label="Province"
        error={state.fieldErrors?.province}
        required
      />

      <div className={styles.row}>
        <Field
          id="areaValue"
          name="areaValue"
          label="Area (optional)"
          type="text"
          inputMode="decimal"
          error={state.fieldErrors?.areaValue}
        />
        <Select
          id="areaUnit"
          name="areaUnit"
          label="Unit"
          placeholder="—"
          options={AREA_UNITS.map((u) => ({ value: u, label: areaUnitLabels[u] }))}
          error={state.fieldErrors?.areaUnit}
        />
      </div>

      <fieldset className={styles.fieldset}>
        <legend className={styles.legend}>Exact location</legend>
        <p className={styles.explain}>
          We store your barangay by default. You can add exact coordinates if you
          want, but you do not have to, and it will not change what you are paid.
        </p>

        <label className={styles.checkbox} htmlFor="shareLocation">
          <input
            id="shareLocation"
            name="shareLocation"
            type="checkbox"
            checked={shareLocation}
            onChange={(event) => setShareLocation(event.target.checked)}
          />
          <span>I agree to share this farm&rsquo;s exact location.</span>
        </label>
        {state.fieldErrors?.shareLocation ? (
          <p className={styles.error} role="alert">
            {state.fieldErrors.shareLocation}
          </p>
        ) : null}

        {shareLocation ? (
          <div className={styles.row}>
            <Field
              id="latitude"
              name="latitude"
              label="Latitude"
              type="text"
              inputMode="decimal"
              error={state.fieldErrors?.latitude}
            />
            <Field
              id="longitude"
              name="longitude"
              label="Longitude"
              type="text"
              inputMode="decimal"
              error={state.fieldErrors?.longitude}
            />
          </div>
        ) : null}
      </fieldset>

      <Button type="submit" pending={pending}>
        Save farm
      </Button>
    </form>
  );
}
