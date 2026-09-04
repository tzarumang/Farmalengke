'use client';

import { Button } from '@/components/ui/Button';
import { Notice } from '@/components/ui/Notice';

/**
 * Error state. Says what to do next and never shows the user a stack trace.
 */
export default function ProfileError({ reset }: { error: Error; reset: () => void }) {
  return (
    <>
      <h1>Something went wrong</h1>
      <Notice tone="error">
        We could not load your profile. This is usually a connection problem.
      </Notice>
      <Button type="button" onClick={reset}>
        Try again
      </Button>
    </>
  );
}
