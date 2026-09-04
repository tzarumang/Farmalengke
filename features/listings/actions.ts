'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import { listingInputSchema } from './schema';

export interface ListingFormState {
  error?: string;
  fieldErrors?: Record<string, string>;
}

export async function createListing(
  _previous: ListingFormState,
  formData: FormData,
): Promise<ListingFormState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const parsed = listingInputSchema.safeParse({
    farmId: formData.get('farmId'),
    commodityId: formData.get('commodityId'),
    variety: formData.get('variety') ?? '',
    quantity: formData.get('quantity'),
    unitCode: formData.get('unitCode'),
    claimedGrade: formData.get('claimedGrade') ?? '',
    askingPrice: formData.get('askingPrice') || undefined,
    availability: formData.get('availability'),
    availableFrom: formData.get('availableFrom') ?? '',
    publish: formData.get('publish') === 'on',
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

  const { error } = await supabase.from('produce_listings').insert({
    farmer_id: userId,
    farm_id: input.farmId,
    commodity_id: input.commodityId,
    variety: input.variety || null,
    quantity: input.quantity,
    unit_code: input.unitCode,
    claimed_grade: input.claimedGrade || null,
    asking_price: input.askingPrice ?? null,
    availability: input.availability,
    available_from: input.availableFrom || null,
    status: input.publish ? 'active' : 'draft',
    // quantity_kg is set by a database trigger from the recorded conversion.
    // Computing it here would let the application and the database disagree
    // about what a sack weighs.
  });

  if (error) {
    // The most likely cause is a unit with no recorded kilogram conversion, which
    // the database refuses rather than guessing. Say that plainly instead of
    // showing "something went wrong".
    const message = /conversion on record/i.test(error.message)
      ? 'We do not have a recorded weight for that unit yet. Choose kilos, or ask the bagsakan to record the conversion.'
      : 'Could not save the listing. Try again.';
    return { error: message };
  }

  revalidatePath('/listings');
  redirect('/listings');
}
