'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Notice } from '@/components/ui/Notice';
import { Select } from '@/components/ui/Select';
import type { Region } from '@/features/reference/types';

import { createCooperative, type CooperativeState } from '../actions';

const initialState: CooperativeState = {};

export function CooperativeForm({ regions }: { regions: Region[] }) {
  const [state, formAction, pending] = useActionState(createCooperative, initialState);

  return (
    <form action={formAction} noValidate>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      {state.message ? <Notice tone="success">{state.message}</Notice> : null}

      <Field
        id="name"
        name="name"
        label="Group name"
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
      <Field id="barangay" name="barangay" label="Barangay" error={state.fieldErrors?.barangay} required />
      <Field
        id="cityMunicipality"
        name="cityMunicipality"
        label="City or municipality"
        error={state.fieldErrors?.cityMunicipality}
        required
      />
      <Field id="province" name="province" label="Province" error={state.fieldErrors?.province} required />

      <Button type="submit" pending={pending}>
        Register group
      </Button>
    </form>
  );
}
