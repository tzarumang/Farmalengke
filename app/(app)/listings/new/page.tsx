import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { listOwnFarms } from '@/features/farms/data';
import {
  ListingForm,
  type ListingFormCommodity,
} from '@/features/listings/components/ListingForm';
import { getVerifiedUserId } from '@/features/profile/data';
import { listCommodities, listUnitsForCommodity } from '@/features/reference/data';

export const metadata: Metadata = { title: 'List produce — Farmalengke' };

export default async function NewListingPage() {
  if (!(await getVerifiedUserId())) redirect('/login');

  const farms = await listOwnFarms();
  if (farms.length === 0) redirect('/farms/new');

  const regionCodes = [...new Set(farms.map((f) => f.regionCode))];

  // Which commodities each of the farmer's regions trades, so the form can narrow
  // the list to what is actually local to the selected farm.
  const perRegion = await Promise.all(
    regionCodes.map(async (code) => ({
      code,
      commodities: await listCommodities(code),
    })),
  );

  const byId = new Map<string, ListingFormCommodity>();
  for (const { code, commodities } of perRegion) {
    for (const commodity of commodities) {
      const existing = byId.get(commodity.id);
      if (existing) {
        existing.regionCodes.push(code);
      } else {
        byId.set(commodity.id, {
          id: commodity.id,
          nameEn: commodity.nameEn,
          nameFil: commodity.nameFil,
          regionCodes: [code],
          unitCodes: [],
        });
      }
    }
  }

  const commodities = [...byId.values()];

  // Only units that have a recorded kilogram conversion for that commodity. The
  // database refuses a write it cannot normalise, so offering an unconvertible
  // unit would only produce a dead end.
  const unitsById = new Map<string, { code: string; nameEn: string; nameFil: string }>();
  await Promise.all(
    commodities.map(async (commodity) => {
      const regionCode = commodity.regionCodes[0] ?? null;
      const units = await listUnitsForCommodity(commodity.id, regionCode);
      commodity.unitCodes = units.map((u) => u.code);
      for (const unit of units) unitsById.set(unit.code, unit);
    }),
  );

  return (
    <>
      <h1>List produce</h1>
      <p>
        Tell buyers what you have. Nothing is offered until you tick the box at the
        bottom, so you can save a draft and come back.
      </p>
      <ListingForm
        farms={farms.map((f) => ({ id: f.id, name: f.name, regionCode: f.regionCode }))}
        commodities={commodities}
        units={[...unitsById.values()]}
      />
    </>
  );
}
