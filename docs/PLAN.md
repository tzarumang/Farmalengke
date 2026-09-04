# Build Plan

Working plan for delivery. The authoritative scope is [`PRD.md`](../PRD.md); this tracks
what is being built right now and what comes next.

## Now (this slice) — M2 slice 3: tiered verification

**Done = a farmer sends what they have, compliance decides with their name on it,
and the tier that decision grants is what the transaction ceilings enforce.**

- [x] Tiered KYC (FR-2) — tier 1 asks for a photograph, tier 2 for a government
      ID and a selfie, with the requirements held as data so the interface and
      the completeness check read the same list
- [x] Identity documents in a private bucket, readable only by their subject and
      compliance, with signed URLs that expire in 60 seconds
- [x] Per-transaction **and** rolling 30-day ceilings, enforced on both sides of a
      trade: the buyer when they place, the farmer when they accept
- [x] Every decision timestamped and attributable; a rejection must say why
- [x] 35 further database assertions; 116 in total

## Next (ordered backlog)

- [ ] **M2 slice 4 — cooperative accounts.** FR-4: group registration, member
      invitations, consolidated listings
- [ ] **M3 — Bagsakan operations.** Intake, grading, inventory, write-off
      (FR-13 to FR-16), including offline capture and conflict-surfacing sync
- [ ] **M5 — Logistics.** Provider onboarding, job assignment, tracking, proof of
      delivery (FR-17 to FR-20)

### Carried forward

- [ ] **The KYC ceilings are placeholders.** Every threshold is a `platform_settings`
      row pending the Q6 legal opinion, so answering Q6 is a configuration change
      rather than a migration — but until it is answered the numbers are ours, not
      counsel's
- [ ] **Nobody is told their application was decided.** They see it on the
      verification page; a message needs the Q8 provider decision, same as FR-8
- [ ] **Document destruction is not scheduled.** §9 sets 5 years after the
      relationship ends. Nothing deletes them yet, and holding biometric data past
      its retention is itself a breach of the rule
- [ ] **Schedule the lapse sweep** (from slice 2)
- [ ] **Notify farmers of a reservation** (from slice 2)
- [ ] **Partial reservation**, if the pilot shows whole-listing is too coarse

## Blocked

- **M4 — Vault.** Blocked on PRD `Q6` (legal opinion on fund custody) per milestone M0.
  M1 leaves a seam for it — see "Decisions" below — but implements no custody.
- **M7 — Pilot.** Blocked on M0 licences.

## Later / parking lot

- M8 analytics: needs ~6 months of transaction history before forecasting can clear the
  G5 accuracy bar. Descriptive reporting comes first.
- Native mobile apps (out of scope per PRD §6)
- SMS/USSD fallback path (FR-31) — a *Should*, promoted to *Must* if PRD assumption 1
  proves wrong

## Decisions & assumptions

| | Decision | Why |
|---|---|---|
| Stack | Next.js App Router + TypeScript + self-hosted Supabase; Stellar/Soroban for the Vault | Fixed by the client |
| Auth | Phone OTP, provider-agnostic | FR-1 requires no email address; farmers are the primary user |
| Roles | Injected into the JWT by a custom access token hook, read from `app_metadata` | `user_metadata` is user-editable and unsafe to authorize from |
| Audit | Append-only by `REVOKE` + trigger + no RLS write policy | FR-28 requires records no role can edit, including administrators |
| Vault seam | M1 defines *who* may act and records *what* they did; it holds no funds | Building custody before the legal opinion (Q6) risks an unusable system |
| Regions | Both Cordillera and Central Luzon | Client answer to Q10. Widens PRD §6, which scopes the MVP to one region — see the note below |
| Commodities | Nine, seeded as reference rows rather than an enum | Changing the set is a data change, not a migration |
| KYC documents | Stored by us, in a private bucket, with a provider seam | Client decision. `kyc_documents.storage_path` is nullable so a verification provider can hold the images later without a schema change |
| Ceilings | Per transaction **and** rolling 30 days | A per-transaction limit alone is defeated by splitting one payment into several |
| Order price | The farmer's asking price, not the platform's published price | Client decision D5. FR-5 amended to carry a price |
| Reservation | Whole-listing | FR-8 aggregates listings rather than splitting them; partial reservation needs quantity bookkeeping this slice does not have |
| Order write path | `place_order()` and `respond_to_order_line()` are SECURITY DEFINER; the tables carry no write policy | The reservation invariants span several statements, so the function is the only way in and owns the authorisation it bypasses |
| Unit conversions | Only the kilogram identity is seeded | A sack weight nobody has measured is an invented number in front of a farmer. Operations records the real ones (Q11) |
| Branding | Neutral accessible tokens | No brand exists yet (PRD Q9); tokens swap without touching components |

## Open scope note

PRD §6 scopes the MVP to a **single bagsakan site, single region, five
commodities**. The answer to Q10 selected **both** regions, which is nine
commodities across two. That is a deliberate client decision, recorded here rather
than silently absorbed: it widens the MVP boundary and, downstream, implies two
pilot sites at M7 instead of one. Worth confirming that consequence is intended
before M7 planning.

## Verification note

Docker is unavailable in the current build environment, so the full Supabase stack cannot
be run here. Migrations and RLS policies are instead verified against a real PostgreSQL 16
server using a shim that reproduces Supabase's `auth` schema (`supabase/tests/`). The
policies are genuinely executed and asserted, not merely written.
