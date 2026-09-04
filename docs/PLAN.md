# Build Plan

Working plan for delivery. The authoritative scope is [`PRD.md`](../PRD.md); this tracks
what is being built right now and what comes next.

## Now (this slice) — M2 slice 2: pricing, browse and orders

**Done = the trading desk publishes a price, a farmer sees it and prices their own
produce, a buyer finds and orders it, and each farmer confirms their own part.**

- [x] Platform buying prices (FR-9) — per commodity, grade and region, schedulable
      ahead, append-only, every publication attributed
- [x] Farmer price view (FR-6) — current bid, 7-day range, source and timestamp on
      every figure, stale after 48 hours
- [x] Asking price on listings (FR-5 as amended) — a draft may be unpriced, an
      offer may not
- [x] Buyer browse with filters (FR-7)
- [x] Orders (FR-8) — reservation, double-sell prevention, per-farmer confirmation,
      lapsing when unanswered
- [x] 31 further database assertions; 81 in total

## Next (ordered backlog)

- [ ] **M2 slice 3 — tiered KYC.** FR-2. Thresholds come from the Q6 legal opinion,
      so the tiers are built but the numbers stay configuration
- [ ] **M2 slice 4 — cooperative accounts.** FR-4: group registration, member
      invitations, consolidated listings
- [ ] **M3 — Bagsakan operations.** Intake, grading, inventory, write-off
      (FR-13 to FR-16), including offline capture and conflict-surfacing sync
- [ ] **M5 — Logistics.** Provider onboarding, job assignment, tracking, proof of
      delivery (FR-17 to FR-20)

### Carried from this slice

- [ ] **Schedule the lapse sweep.** `expire_lapsed_reservations()` is called
      opportunistically before reads, so nothing ever *displays* as pending past its
      deadline. A deployed instance should also run it on a schedule (pg_cron) so
      listings free up without waiting for someone to look
- [ ] **Notify farmers of a reservation.** FR-8 says the farmer "is notified"; today
      they see it on the orders page. SMS or push needs the provider decision in Q8
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
