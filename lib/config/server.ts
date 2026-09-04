import 'server-only';

import { z } from 'zod';

/**
 * Validated server-side configuration.
 *
 * Every secret the Node runtime needs is read here and nowhere else, so a missing or
 * malformed variable fails loudly at startup rather than as a confusing 500 during a
 * farmer's signup. `server-only` makes the build fail if a Client Component ever
 * imports this module, which is a compile-time guarantee that the secret key cannot
 * reach the browser bundle.
 */
const serverEnvSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url({
    message: 'NEXT_PUBLIC_SUPABASE_URL must be the full URL of the Supabase instance.',
  }),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),

  /**
   * Bypasses row-level security. It exists for administrative operations that no
   * user should be able to perform through a policy — never for convenience.
   */
  SUPABASE_SECRET_KEY: z.string().min(1).optional(),

  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
});

export type ServerConfig = z.infer<typeof serverEnvSchema>;

let cached: ServerConfig | null = null;

export function getServerConfig(): ServerConfig {
  if (cached) return cached;

  const parsed = serverEnvSchema.safeParse(process.env);

  if (!parsed.success) {
    const detail = parsed.error.issues
      .map((issue) => `  ${issue.path.join('.')}: ${issue.message}`)
      .join('\n');
    throw new Error(
      `Invalid server configuration. Copy .env.example to .env.local and fill it in.\n${detail}`,
    );
  }

  cached = parsed.data;
  return cached;
}

/**
 * The secret key, demanded explicitly at the point of use.
 *
 * Requiring a caller to reach for this by name — rather than reading it off a config
 * object — makes every privileged call site greppable in review.
 */
export function requireSecretKey(): string {
  const { SUPABASE_SECRET_KEY } = getServerConfig();
  if (!SUPABASE_SECRET_KEY) {
    throw new Error(
      'SUPABASE_SECRET_KEY is not set. It is required only for administrative ' +
        'operations that bypass row-level security.',
    );
  }
  return SUPABASE_SECRET_KEY;
}
