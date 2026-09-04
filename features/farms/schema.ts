import { z } from 'zod';

export const AREA_UNITS = ['hectare', 'square_metre'] as const;

export const areaUnitLabels: Record<(typeof AREA_UNITS)[number], string> = {
  hectare: 'Hectares',
  square_metre: 'Square metres',
};

/**
 * A farm as the farmer describes it.
 *
 * Coordinates are only accepted alongside explicit consent. The database enforces
 * the same rule, so a request that bypasses this schema still cannot store a
 * location the farmer did not agree to.
 */
export const farmInputSchema = z
  .object({
    name: z.string().trim().min(1, 'Give the farm a name you will recognise.').max(120),
    regionCode: z.string().trim().min(1, 'Choose a region.'),
    barangay: z.string().trim().min(1, 'Enter the barangay.').max(120),
    cityMunicipality: z.string().trim().min(1, 'Enter the city or municipality.').max(120),
    province: z.string().trim().min(1, 'Enter the province.').max(120),

    areaValue: z
      .string()
      .trim()
      .optional()
      .transform((v) => (v ? Number(v) : undefined))
      .refine((v) => v === undefined || (Number.isFinite(v) && v > 0), {
        message: 'Area must be a number greater than zero.',
      }),
    areaUnit: z.enum(AREA_UNITS).optional(),

    shareLocation: z.boolean().default(false),
    latitude: z
      .string()
      .trim()
      .optional()
      .transform((v) => (v ? Number(v) : undefined))
      .refine((v) => v === undefined || (Number.isFinite(v) && v >= -90 && v <= 90), {
        message: 'Latitude must be between -90 and 90.',
      }),
    longitude: z
      .string()
      .trim()
      .optional()
      .transform((v) => (v ? Number(v) : undefined))
      .refine((v) => v === undefined || (Number.isFinite(v) && v >= -180 && v <= 180), {
        message: 'Longitude must be between -180 and 180.',
      }),
  })
  .refine((v) => (v.areaValue === undefined) === (v.areaUnit === undefined), {
    message: 'Enter both the area and its unit, or leave both blank.',
    path: ['areaValue'],
  })
  .refine((v) => (v.latitude === undefined) === (v.longitude === undefined), {
    message: 'A location needs both latitude and longitude.',
    path: ['latitude'],
  })
  .refine((v) => v.latitude === undefined || v.shareLocation, {
    message: 'Tick the consent box before sharing an exact location.',
    path: ['shareLocation'],
  });

export type FarmInput = z.infer<typeof farmInputSchema>;

export interface Farm {
  id: string;
  name: string;
  regionCode: string;
  barangay: string;
  cityMunicipality: string;
  province: string;
  areaValue: number | null;
  areaUnit: (typeof AREA_UNITS)[number] | null;
  hasSharedLocation: boolean;
  createdAt: string;
}

/** "0.5 hectares", or a plain dash when the farmer has not said. */
export function formatArea(farm: Pick<Farm, 'areaValue' | 'areaUnit'>): string {
  if (farm.areaValue === null || farm.areaUnit === null) return '—';
  const unit = farm.areaUnit === 'hectare' ? 'ha' : 'm²';
  return `${farm.areaValue} ${unit}`;
}
