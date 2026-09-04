import 'server-only';

import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

import { getServerConfig, requireSecretKey } from '@/lib/config/server';

/**
 * Request-scoped Supabase client for Server Components, Server Actions, and Route
 * Handlers. Carries the caller's session, so every query it runs is subject to row
 * level security — which is the point.
 */
export async function createClient() {
  const cookieStore = await cookies();
  const { NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY } = getServerConfig();

  return createServerClient(NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Called during a Server Component render, where cookies are read-only.
          // The proxy refreshes the session, so this is safe to ignore.
        }
      },
    },
  });
}

/**
 * Client that bypasses row-level security.
 *
 * Reserve this for operations that genuinely cannot be expressed as a policy. If you
 * are reaching for it to read a user's own data, use {@link createClient} instead —
 * needing this to read ordinary data usually means a policy is missing.
 */
export function createAdminClient() {
  const { NEXT_PUBLIC_SUPABASE_URL } = getServerConfig();

  return createServerClient(NEXT_PUBLIC_SUPABASE_URL, requireSecretKey(), {
    cookies: {
      getAll: () => [],
      setAll: () => {
        /* An administrative client carries no user session by design. */
      },
    },
  });
}
