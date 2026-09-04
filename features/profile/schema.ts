import { z } from 'zod';

export const SUPPORTED_LANGUAGES = ['fil', 'en', 'ceb', 'ilo', 'hil'] as const;

export const languageLabels: Record<(typeof SUPPORTED_LANGUAGES)[number], string> = {
  fil: 'Filipino',
  en: 'English',
  ceb: 'Cebuano',
  ilo: 'Ilocano',
  hil: 'Hiligaynon',
};

/**
 * Only the fields a user may set on themselves.
 *
 * kyc_tier and status are absent on purpose: they are set by compliance review, and
 * the database rejects a self-change even if this schema were bypassed. Two
 * independent layers, because the database one is the one that actually holds.
 */
export const updateProfileSchema = z.object({
  displayName: z.string().trim().min(1, 'Enter a name.').max(120),
  preferredLanguage: z.enum(SUPPORTED_LANGUAGES),
  barangay: z.string().trim().max(120).optional().or(z.literal('')),
  cityMunicipality: z.string().trim().max(120).optional().or(z.literal('')),
  province: z.string().trim().max(120).optional().or(z.literal('')),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;

export interface Profile {
  id: string;
  mobileNumber: string;
  displayName: string | null;
  preferredLanguage: string;
  barangay: string | null;
  cityMunicipality: string | null;
  province: string | null;
  kycTier: 'tier_0' | 'tier_1' | 'tier_2';
  status: 'pending' | 'active' | 'suspended' | 'closed';
  roles: string[];
}
