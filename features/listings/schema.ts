import { z } from 'zod';

export const LISTING_AVAILABILITY = ['available_now', 'expected'] as const;

export const availabilityLabels: Record<(typeof LISTING_AVAILABILITY)[number], string> = {
  available_now: 'Ready now',
  expected: 'Expected later',
};

export const LISTING_STATUSES = [
  'draft',
  'active',
  'committed',
  'withdrawn',
  'expired',
] as const;

export const statusLabels: Record<(typeof LISTING_STATUSES)[number], string> = {
  draft: 'Draft',
  active: 'Offered',
  committed: 'Reserved',
  withdrawn: 'Withdrawn',
  expired: 'Expired',
};

export const listingInputSchema = z
  .object({
    farmId: z.string().uuid('Choose which farm this produce is from.'),
    commodityId: z.string().uuid('Choose what you are selling.'),
    variety: z.string().trim().max(120).optional().or(z.literal('')),

    quantity: z
      .string()
      .trim()
      .min(1, 'Enter how much you have.')
      .transform(Number)
      .refine((v) => Number.isFinite(v) && v > 0, {
        message: 'Quantity must be a number greater than zero.',
      }),
    unitCode: z.string().trim().min(1, 'Choose a unit.'),

    claimedGrade: z.string().trim().max(60).optional().or(z.literal('')),

    availability: z.enum(LISTING_AVAILABILITY),
    availableFrom: z.string().trim().optional().or(z.literal('')),

    publish: z.boolean().default(false),
  })
  .refine((v) => v.availability !== 'expected' || Boolean(v.availableFrom), {
    message: 'Say roughly when it will be ready.',
    path: ['availableFrom'],
  });

export type ListingInput = z.infer<typeof listingInputSchema>;

export interface Listing {
  id: string;
  farmName: string;
  commodityNameEn: string;
  commodityNameFil: string;
  variety: string | null;
  quantity: number;
  unitCode: string;
  quantityKg: number;
  claimedGrade: string | null;
  availability: (typeof LISTING_AVAILABILITY)[number];
  availableFrom: string | null;
  status: (typeof LISTING_STATUSES)[number];
  createdAt: string;
}
