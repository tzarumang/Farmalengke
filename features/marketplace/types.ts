/**
 * Marketplace shapes.
 *
 * Separate from `data.ts`, which is `server-only`. Client components need these,
 * and importing them from the server module survives only because `import type`
 * is erased — a real bundle leak the moment somebody drops the keyword.
 */

export interface MarketFilters {
  commodityId?: string;
  regionCode?: string;
  minQuantityKg?: number;
  availableBy?: string;
}

export interface MarketListing {
  id: string;
  commodityNameEn: string;
  commodityNameFil: string;
  variety: string | null;
  quantity: number;
  unitCode: string;
  quantityKg: number;
  askingPricePerKg: number;
  lineTotal: number;
  currency: string;
  claimedGrade: string | null;
  availability: 'available_now' | 'expected';
  availableFrom: string | null;
  barangay: string;
  cityMunicipality: string;
  province: string;
  regionCode: string;
}
