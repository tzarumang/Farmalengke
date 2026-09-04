import { z } from 'zod';

export const MEMBERSHIP_STATUSES = [
  'invited',
  'active',
  'declined',
  'left',
  'removed',
] as const;
export type MembershipStatus = (typeof MEMBERSHIP_STATUSES)[number];

export const membershipStatusLabels: Record<MembershipStatus, string> = {
  invited: 'Invited',
  active: 'Member',
  declined: 'Declined',
  left: 'Left',
  removed: 'Removed',
};

export const cooperativeInputSchema = z.object({
  name: z.string().trim().min(1, 'Give the group a name.').max(160),
  regionCode: z.string().trim().min(1, 'Choose a region.'),
  barangay: z.string().trim().min(1, 'Enter the barangay.').max(120),
  cityMunicipality: z.string().trim().min(1, 'Enter the city or municipality.').max(120),
  province: z.string().trim().min(1, 'Enter the province.').max(120),
});

export const inviteInputSchema = z.object({
  cooperativeId: z.string().uuid(),
  mobileNumber: z
    .string()
    .trim()
    .transform((v) => v.replace(/[\s()-]/g, ''))
    .pipe(
      z
        .string()
        .regex(/^(\+63|0)9\d{9}$/, 'Enter a Philippine mobile number, like 0917 123 4567.'),
    )
    .transform((v) => (v.startsWith('0') ? `+63${v.slice(1)}` : v)),
});

export interface Member {
  membershipId: string;
  farmerId: string;
  displayName: string | null;
  mobileNumber: string;
  status: MembershipStatus;
  invitedAt: string;
}

export interface Cooperative {
  id: string;
  name: string;
  officerId: string;
  regionCode: string;
  barangay: string;
  cityMunicipality: string;
  province: string;
  isOfficer: boolean;
  members: Member[];
}

export interface Invitation {
  membershipId: string;
  cooperativeId: string;
  cooperativeName: string;
  invitedAt: string;
}

export interface Contribution {
  farmerId: string;
  displayName: string | null;
  quantityKg: number;
}
