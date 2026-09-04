import { z } from 'zod';

/** A money figure, always shown with its source and timestamp (FR-6). */
export interface SourcedPrice {
  pricePerKg: number;
  currency: string;
  /** Where the figure came from. FR-6 forbids showing a price without this. */
  source: string;
  observedAt: string;
}

export interface PriceView {
  commodityId: string;
  commodityNameEn: string;
  commodityNameFil: string;
  regionCode: string;
  /** Null when nothing has been published — render "no price yet", never a zero. */
  current: SourcedPrice | null;
  sevenDayLow: number | null;
  sevenDayHigh: number | null;
  /** FR-6: a figure older than 48 hours is marked stale rather than shown plainly. */
  isStale: boolean;
}

export const publishPriceSchema = z.object({
  commodityId: z.string().uuid('Choose a commodity.'),
  regionCode: z.string().trim().min(1, 'Choose a region.'),
  grade: z.string().trim().max(60).optional().or(z.literal('')),
  pricePerKg: z
    .string()
    .trim()
    .min(1, 'Enter a price.')
    .transform(Number)
    .refine((v) => Number.isFinite(v) && v > 0, {
      message: 'Price must be a number greater than zero.',
    }),
  effectiveFrom: z.string().trim().optional().or(z.literal('')),
});

export type PublishPriceInput = z.infer<typeof publishPriceSchema>;

export const STALE_AFTER_HOURS = 48;

export function formatPeso(value: number): string {
  return new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    minimumFractionDigits: 2,
  }).format(value);
}
