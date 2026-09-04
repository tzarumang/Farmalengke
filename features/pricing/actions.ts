'use server';

import { revalidatePath } from 'next/cache';

import { getVerifiedRoles, getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import { publishPriceSchema } from './schema';

export interface PublishPriceState {
  error?: string;
  published?: boolean;
  fieldErrors?: Record<string, string>;
}

/**
 * Publishes a platform buying price (FR-9).
 *
 * `created_by` is taken from the session, never the form: FR-9 requires every
 * price change to be attributable, and a self-declared author is not attribution.
 * The database enforces the same rule in its insert policy.
 */
export async function publishPrice(
  _previous: PublishPriceState,
  formData: FormData,
): Promise<PublishPriceState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const roles = await getVerifiedRoles();
  if (!roles.includes('trading_desk') && !roles.includes('admin')) {
    return { error: 'Only the trading desk can publish prices.' };
  }

  const parsed = publishPriceSchema.safeParse({
    commodityId: formData.get('commodityId'),
    regionCode: formData.get('regionCode'),
    grade: formData.get('grade') ?? '',
    pricePerKg: formData.get('pricePerKg'),
    effectiveFrom: formData.get('effectiveFrom') ?? '',
  });

  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const issue of parsed.error.issues) {
      const key = String(issue.path[0] ?? 'form');
      fieldErrors[key] ??= issue.message;
    }
    return { error: 'Check the highlighted fields.', fieldErrors };
  }

  const input = parsed.data;
  const supabase = await createClient();

  const { error } = await supabase.from('platform_prices').insert({
    commodity_id: input.commodityId,
    region_code: input.regionCode,
    grade: input.grade || null,
    price_per_kg: input.pricePerKg,
    // Empty means "now". A future value schedules the price, per FR-9.
    effective_from: input.effectiveFrom ? new Date(input.effectiveFrom).toISOString() : undefined,
    created_by: userId,
  });

  if (error) return { error: 'Could not publish the price. Try again.' };

  revalidatePath('/trading/prices');
  revalidatePath('/prices');
  return { published: true };
}
