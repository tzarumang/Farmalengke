/**
 * Reference-data shapes.
 *
 * Deliberately separate from `data.ts`, which is `server-only`. Client components
 * need these types, and importing them from the server module would work only
 * because `import type` is erased at compile time — a fragile arrangement that
 * turns into a real bundle leak the moment somebody drops the `type` keyword.
 */

export interface Region {
  code: string;
  name: string;
}

export interface Commodity {
  id: string;
  code: string;
  nameEn: string;
  nameFil: string;
}

export interface TradeUnit {
  code: string;
  nameEn: string;
  nameFil: string;
}
