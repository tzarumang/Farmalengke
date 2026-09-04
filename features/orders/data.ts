import 'server-only';

import { getVerifiedUserId } from '@/features/profile/data';
import { createClient } from '@/lib/supabase/server';

import type { Order, OrderLine } from './schema';

interface LineRow {
  id: string;
  listing_id: string;
  quantity_kg: string | number;
  price_per_kg: string | number;
  line_total: string | number;
  status: OrderLine['status'];
  farmer_id: string;
  produce_listings:
    | { commodities: { name_en: string; name_fil: string } | { name_en: string; name_fil: string }[] | null }
    | { commodities: { name_en: string; name_fil: string } | { name_en: string; name_fil: string }[] | null }[]
    | null;
}

interface OrderRow {
  id: string;
  status: Order['status'];
  delivery_date: string;
  delivery_barangay: string;
  delivery_city: string;
  delivery_province: string;
  total_price: string | number;
  currency: string;
  confirmation_deadline: string;
  created_at: string;
  order_lines: LineRow[] | null;
}

function one<T>(value: T | T[] | null | undefined): T | null {
  if (!value) return null;
  return Array.isArray(value) ? (value[0] ?? null) : value;
}

const ORDER_COLUMNS = `
  id, status, delivery_date, delivery_barangay, delivery_city, delivery_province,
  total_price, currency, confirmation_deadline, created_at,
  order_lines(
    id, listing_id, quantity_kg, price_per_kg, line_total, status, farmer_id,
    produce_listings(commodities(name_en, name_fil))
  )
`;

function toOrder(row: OrderRow, now: number): Order {
  return {
    id: row.id,
    status: row.status,
    deliveryDate: row.delivery_date,
    deliveryBarangay: row.delivery_barangay,
    deliveryCity: row.delivery_city,
    deliveryProvince: row.delivery_province,
    totalPrice: Number(row.total_price),
    currency: row.currency,
    confirmationDeadline: row.confirmation_deadline,
    isPastDeadline: new Date(row.confirmation_deadline).getTime() < now,
    createdAt: row.created_at,
    lines: (row.order_lines ?? []).map((line) => {
      const listing = one(line.produce_listings);
      const commodity = one(listing?.commodities);
      return {
        id: line.id,
        listingId: line.listing_id,
        commodityNameEn: commodity?.name_en ?? 'Unknown',
        commodityNameFil: commodity?.name_fil ?? 'Unknown',
        quantityKg: Number(line.quantity_kg),
        pricePerKg: Number(line.price_per_kg),
        lineTotal: Number(line.line_total),
        status: line.status,
        farmerName: null,
      };
    }),
  };
}

/**
 * Orders the signed-in user is a party to.
 *
 * A buyer sees the orders they placed; a farmer sees orders touching their own
 * listings, and only their own lines on them — enforced by policy, not by this
 * query. Lapsed reservations are swept first so nothing displays as still
 * pending after its window has closed.
 */
export async function listOwnOrders(): Promise<Order[]> {
  const userId = await getVerifiedUserId();
  if (!userId) return [];

  const supabase = await createClient();
  await supabase.rpc('expire_lapsed_reservations');

  const { data, error } = await supabase
    .from('orders')
    .select(ORDER_COLUMNS)
    .order('created_at', { ascending: false });

  if (error || !data) return [];

  // One clock reading for the whole page, taken after the lapse sweep above.
  const now = Date.now();
  return (data as unknown as OrderRow[]).map((row) => toOrder(row, now));
}
