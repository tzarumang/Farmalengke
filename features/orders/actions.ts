'use server';

import { revalidatePath } from 'next/cache';

import { getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import { placeOrderSchema } from './schema';

/**
 * Whether a database error is a verification ceiling, whose message is written
 * for the person who hit it.
 */
function isVerificationBlock(message: string): boolean {
  return (
    /not verified yet/i.test(message) ||
    /allows up to/i.test(message) ||
    /in 30 days/i.test(message)
  );
}

export interface PlaceOrderState {
  error?: string;
  orderId?: string;
  fieldErrors?: Record<string, string>;
}

/**
 * Places an order against one or more listings (FR-8).
 *
 * The work happens in the database function, not here. Reserving a listing means
 * checking it is still on offer, snapshotting its price, marking it committed and
 * writing the line — and those must not half-happen if two buyers arrive at once.
 * The function holds them in one statement with a row lock; this action only
 * validates input and reports the outcome.
 */
export async function placeOrder(
  _previous: PlaceOrderState,
  formData: FormData,
): Promise<PlaceOrderState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const parsed = placeOrderSchema.safeParse({
    listingIds: formData.getAll('listingIds').map(String),
    deliveryDate: formData.get('deliveryDate'),
    deliveryBarangay: formData.get('deliveryBarangay'),
    deliveryCity: formData.get('deliveryCity'),
    deliveryProvince: formData.get('deliveryProvince'),
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

  const { data, error } = await supabase.rpc('place_order', {
    p_listing_ids: input.listingIds,
    p_delivery_date: input.deliveryDate,
    p_delivery_barangay: input.deliveryBarangay,
    p_delivery_city: input.deliveryCity,
    p_delivery_province: input.deliveryProvince,
  });

  if (error) {
    // A verification block is already a sentence written for the person reading
    // it, naming the limit and the document that lifts it — FR-2 requires exactly
    // that, so it is passed through rather than flattened into a generic failure.
    if (isVerificationBlock(error.message)) return { error: error.message };

    // "No longer available" is the ordinary race, not a fault: somebody else
    // reserved it while this buyer was deciding. Say that, rather than "error".
    const message = /no longer available/i.test(error.message)
      ? 'Someone else reserved one of those listings first. Refresh and try again.'
      : /asking price/i.test(error.message)
        ? 'One of those listings has no price on it and cannot be ordered.'
        : 'Could not place the order. Try again.';
    return { error: message };
  }

  revalidatePath('/orders');
  revalidatePath('/market');
  return { orderId: typeof data === 'string' ? data : undefined };
}

export interface RespondState {
  error?: string;
  done?: boolean;
}

/** A farmer confirms or declines their own line of an order (FR-8). */
export async function respondToOrderLine(
  _previous: RespondState,
  formData: FormData,
): Promise<RespondState> {
  const userId = await getVerifiedUserId();
  if (!userId) return { error: 'Your session has expired. Sign in again.' };

  const lineId = String(formData.get('lineId') ?? '');
  const accept = formData.get('decision') === 'confirm';

  if (!lineId) return { error: 'Missing order line.' };

  const supabase = await createClient();
  const { error } = await supabase.rpc('respond_to_order_line', {
    p_line_id: lineId,
    p_accept: accept,
  });

  if (error) {
    if (isVerificationBlock(error.message)) return { error: error.message };

    const message = /window has closed/i.test(error.message)
      ? 'The time to answer this order has passed, so it went back on the market.'
      : /already been answered/i.test(error.message)
        ? 'That order has already been answered.'
        : 'Could not record your answer. Try again.';
    return { error: message };
  }

  revalidatePath('/orders');
  revalidatePath('/listings');
  return { done: true };
}
