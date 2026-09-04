'use client';

import { Button } from '@/components/ui/Button';
import { Notice } from '@/components/ui/Notice';

export default function CooperativeError({ reset }: { error: Error; reset: () => void }) {
  return (
    <>
      <h1>Something went wrong</h1>
      <Notice tone="error">We could not load your group. Try again.</Notice>
      <Button type="button" onClick={reset}>Try again</Button>
    </>
  );
}
