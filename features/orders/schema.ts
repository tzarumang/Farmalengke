import { z } from 'zod';

export const ORDER_STATUSES = [
  'pending',
  'confirmed',
  'partial',
  'declined',
  'cancelled',
] as const;

export const orderStatusLabels: Record<(typeof ORDER_STATUSES)[number], string> = {
  pending: 'Waiting for farmers',
  confirmed: 'Confirmed',
  partial: 'Partly confirmed',
  declined: 'Declined',
  cancelled: 'Cancelled',
};

export const ORDER_LINE_STATUSES = [
  'pending',
  'confirmed',
  'declined',
  'lapsed',
  'cancelled',
] as const;

export const orderLineStatusLabels: Record<(typeof ORDER_LINE_STATUSES)[number], string> = {
  pending: 'Waiting for you',
  confirmed: 'Confirmed',
  declined: 'Declined',
  lapsed: 'Expired',
  cancelled: 'Cancelled',
};

export const placeOrderSchema = z.object({
  listingIds: z
    .array(z.string().uuid())
    .min(1, 'Choose at least one listing.')
    .max(50, 'An order can cover at most 50 listings.'),
  deliveryDate: z.string().trim().min(1, 'Choose a delivery date.'),
  deliveryBarangay: z.string().trim().min(1, 'Enter the barangay.').max(120),
  deliveryCity: z.string().trim().min(1, 'Enter the city or municipality.').max(120),
  deliveryProvince: z.string().trim().min(1, 'Enter the province.').max(120),
});

export interface OrderLine {
  id: string;
  listingId: string;
  commodityNameEn: string;
  commodityNameFil: string;
  quantityKg: number;
  pricePerKg: number;
  lineTotal: number;
  status: (typeof ORDER_LINE_STATUSES)[number];
  farmerName: string | null;
}

export interface Order {
  id: string;
  status: (typeof ORDER_STATUSES)[number];
  deliveryDate: string;
  deliveryBarangay: string;
  deliveryCity: string;
  deliveryProvince: string;
  totalPrice: number;
  currency: string;
  confirmationDeadline: string;
  /**
   * Whether the confirmation window has closed, resolved when the order is read.
   * Deriving it during render would mean calling an impure clock mid-render, and
   * would let two parts of one page disagree about the time.
   */
  isPastDeadline: boolean;
  createdAt: string;
  lines: OrderLine[];
}
