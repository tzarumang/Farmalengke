# Build Plan

Working plan for delivery. The authoritative scope is [`PRD.md`](../PRD.md); this tracks
what is being built right now and what comes next.

## Now (this slice) — M1 Foundation

**Done = a farmer can sign up with a mobile number, land on their profile, and the whole
path is enforced by the database and recorded in an immutable audit trail.**

- [x] Repository structure, TypeScript, Next.js App Router scaffold
- [x] Validated server-only configuration; `.env.example` only, no secrets committed
- [x] Schema: profiles, role assignment, audit log
- [x] Row-level security on every table, deny-by-default, with policies proven by tests
- [x] Roles in the JWT via a custom access token hook (not user-editable metadata)
- [x] Append-only audit logging, enforced by grants and triggers, not convention
- [x] Phone OTP auth (provider-agnostic — works against the local stack, needs only
      credentials to go live)
- [x] Design tokens and accessible UI primitives with real loading/empty/error states
- [x] CI: typecheck, lint, build, and a migration + RLS test run

## Next (ordered backlog)

- [ ] **M2 — Farmer & listing.** Tiered KYC (FR-2), farm records (FR-3), cooperative
      accounts (FR-4), produce listings (FR-5), price display (FR-6), buyer browse and
      order (FR-7 to FR-9)
- [ ] **M3 — Bagsakan operations.** Intake, grading, inventory, write-off (FR-13 to
      FR-16), including offline capture and conflict-surfacing sync
- [ ] **M5 — Logistics.** Provider onboarding, job assignment, tracking, proof of
      delivery (FR-17 to FR-20)

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
| Location | Barangay text by default, no GPS column yet | PRD §9 data minimisation; GPS needs explicit per-farm consent (M2) |
| Branding | Neutral accessible tokens | No brand exists yet (PRD Q9); tokens swap without touching components |

## Verification note

Docker is unavailable in the current build environment, so the full Supabase stack cannot
be run here. Migrations and RLS policies are instead verified against a real PostgreSQL 16
server using a shim that reproduces Supabase's `auth` schema (`supabase/tests/`). The
policies are genuinely executed and asserted, not merely written.
