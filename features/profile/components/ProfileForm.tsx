'use client';

import { useActionState } from 'react';

import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Notice } from '@/components/ui/Notice';

import { updateOwnProfile, type ProfileFormState } from '../actions';
import { SUPPORTED_LANGUAGES, languageLabels, type Profile } from '../schema';

import styles from './ProfileForm.module.css';

const initialState: ProfileFormState = {};

export function ProfileForm({ profile }: { profile: Profile }) {
  const [state, formAction, pending] = useActionState(updateOwnProfile, initialState);

  return (
    <form action={formAction} noValidate>
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}
      {state.saved ? <Notice tone="success">Your details are saved.</Notice> : null}

      <Field
        id="displayName"
        name="displayName"
        label="Your name"
        defaultValue={profile.displayName ?? ''}
        autoComplete="name"
        required
      />

      <div className={styles.field}>
        <label htmlFor="preferredLanguage" className={styles.label}>
          Language
        </label>
        <select
          id="preferredLanguage"
          name="preferredLanguage"
          className={styles.select}
          defaultValue={profile.preferredLanguage}
        >
          {SUPPORTED_LANGUAGES.map((code) => (
            <option key={code} value={code}>
              {languageLabels[code]}
            </option>
          ))}
        </select>
      </div>

      <Field
        id="barangay"
        name="barangay"
        label="Barangay"
        defaultValue={profile.barangay ?? ''}
        hint="We store your barangay, not your exact location."
      />
      <Field
        id="cityMunicipality"
        name="cityMunicipality"
        label="City or municipality"
        defaultValue={profile.cityMunicipality ?? ''}
      />
      <Field
        id="province"
        name="province"
        label="Province"
        defaultValue={profile.province ?? ''}
      />

      <Button type="submit" pending={pending}>
        Save details
      </Button>
    </form>
  );
}
