import { z } from 'zod';

/**
 * Philippine mobile numbers in E.164.
 *
 * The PRD targets the Philippines first but is architected for other markets, so the
 * stored format is international from the start — retrofitting E.164 onto a column of
 * local "09xx" strings later is a migration nobody enjoys.
 */
export const phMobileNumber = z
  .string()
  .trim()
  .transform((value) => value.replace(/[\s()-]/g, ''))
  .pipe(
    z
      .string()
      .regex(
        /^(\+63|0)9\d{9}$/,
        'Enter a Philippine mobile number, for example 0917 123 4567.',
      ),
  )
  .transform((value) => (value.startsWith('0') ? `+63${value.slice(1)}` : value));

export const requestOtpSchema = z.object({
  mobileNumber: phMobileNumber,
});

export const verifyOtpSchema = z.object({
  mobileNumber: phMobileNumber,
  token: z
    .string()
    .trim()
    .regex(/^\d{6}$/, 'The code is 6 digits.'),
});

export type RequestOtpInput = z.infer<typeof requestOtpSchema>;
export type VerifyOtpInput = z.infer<typeof verifyOtpSchema>;
