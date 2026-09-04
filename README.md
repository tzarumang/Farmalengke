# Farmalengke

> A global effort to help improve farming efficiency.

Farmalengke is an agricultural trading platform that connects smallholder farmers to
buyers through both a physical consolidation point — the *bagsakan*, or trading port —
and a digital equivalent. It digitises the bagsakan rather than replacing it: farmers keep
a physical place to deliver, and the platform adds price transparency, guaranteed offtake,
forward commitments, and pre-harvest cash.

**The objective:** increase the share of the final selling price that reaches the farmer,
while giving buyers dependable volume and quality.

The first market is the Philippines, with the architecture prepared for later expansion.

## Status

**Pre-alpha — no application code yet.** The requirements are drafted and the scope is
agreed; implementation has not started.

The [PRD](PRD.md) is a **v0.1 draft, not a baseline**. Fifteen open questions remain, and
one of them blocks the critical path — see [What has to happen first](#what-has-to-happen-first).

## The problem

Philippine agricultural supply chains run through long trader chains. Produce passes
through several intermediaries, each taking margin, and smallholders — who lack storage,
transport, price information, and pre-harvest liquidity — have weak bargaining power at
the point of sale.

> *"When my crop is ready, I need to convert it to cash quickly and at a fair price,
> without losing it to spoilage or being forced to accept whatever the buyer at the
> bagsakan offers me that morning."*

Buyers have the mirror-image problem: inconsistent volume and quality, and no way to plan
supply. Today both sides rely on personal networks and text messages, none of which is
recorded — which is why neither side can build the track record that would earn them
better terms.

## How it works

Farmalengke operates as **both** a principal buyer and a marketplace:

- **As principal buyer**, the platform purchases produce outright at agreed prices,
  carrying inventory and price risk. This is what solves the cold-start problem — a farmer
  never has to wait for a buyer to appear.
- **As a marketplace**, third-party buyers transact directly with farmers for a commission.

## Capabilities

| Area | What it does |
|------|--------------|
| **Farmer signup** | Mobile-number registration with tiered KYC, farm records, and cooperative/group accounts |
| **Digital trading port** | Produce listings, transparent price display with sourced figures, buyer browse and ordering |
| **Bagsakan operations** | Intake, grading and weighing with the farmer present, inventory tracking, spoilage recording |
| **Forward contracts** | Buyers commit now to a future harvest at an agreed price, giving farmers certainty |
| **Logistics** | Signup for freelance and small-fleet delivery providers, job assignment, tracking, proof of delivery |
| **Predictive analytics** | Yield and price forecasting to support planting and forward-contracting decisions |
| **Vault** | Escrow, prepayment against committed deliveries, settlement, and cash-out to Philippine rails |

**Forward contracts are commercial supply agreements, not financial instruments.** They are
non-transferable by design, and speculation by parties who do not intend to take or make
delivery is explicitly out of scope. This is an enforced control, not a preference.

## Goals

The PRD tracks seven goals with measurable KPIs. In short:

| | Goal |
|---|------|
| **G1** | Raise the share of final sale price reaching the farmer |
| **G2** | Reduce post-harvest loss |
| **G3** | Give buyers dependable supply |
| **G4** | Give farmers pre-harvest liquidity |
| **G5** | Improve planting and pricing decisions |
| **G6** | Establish viable platform unit economics |
| **G7** | Operate lawfully |

Every requirement in the PRD traces back to one of these. See [PRD §5](PRD.md#5-goals--success-metrics)
for the targets and how each is measured.

> **On G1's target.** The PRD sets a 15% improvement in farmgate price realization, but
> that number currently has **no measured baseline** behind it. Establishing one is an open
> question (Q1), not a settled fact.

## Design principles

These follow from who the users are, not from taste:

1. **Money is always legible.** Amounts in pesos, large, with the direction of movement
   unmistakable.
2. **Nothing hidden behind literacy.** Every critical action works from an icon and a
   number.
3. **The network is assumed hostile.** Offline, slow, and stale states are designed, not
   accidents. "Loading" forever is a defect.
4. **Irreversible actions look irreversible.** Accepting a contract is visually distinct
   from browsing.
5. **The physical and the digital agree.** What the operator's screen says must match the
   receipt in the farmer's hand.

A farmer's balance is displayed in pesos regardless of what settles it. The stablecoin is
plumbing the farmer should never have to reason about.

## Technology

| Layer | Choice |
|-------|--------|
| Frontend & API | Next.js (App Router), TypeScript |
| Database, auth, storage | Supabase, **self-hosted** |
| Vault settlement | Stellar, with a Soroban smart contract |
| Settlement asset | A Stellar-issued stablecoin (issuer to be selected) |

Self-hosting Supabase means this project owns Postgres operations, backups, and upgrades.
That is a deliberate client decision with a real cost attached — see RISK-5.

## What has to happen first

**The critical path runs through law, not engineering.**

The Vault holds customer funds as a platform-custodied stablecoin, and prepayments are
advanced against future harvests. In the Philippines this likely requires BSP Virtual
Asset Service Provider registration, and the advances may constitute lending. A written
legal opinion is **milestone M0**, ahead of any Vault code, because building it before the
legal position is settled risks producing a system that cannot lawfully be operated.

The Vault is designed so a licensed third-party custodian can be substituted without
redesigning the trading platform. That is the hedge if the opinion comes back badly.

Two open questions unblock the most: **Q12** (who has authority to sign off) and **Q10**
(which region and which five commodities for the MVP).

## Repository layout

```
.
├── PRD.md           The product requirements document (v0.1 draft)
├── docs/
│   ├── prd/
│   │   ├── PRD.pdf        Rendered PRD
│   │   └── SIGNOFF-LOG.md Gate sign-offs and change control
│   └── roadmap.md         Early direction notes (superseded by PRD §13)
├── .github/         Issue and pull request templates
├── CONTRIBUTING.md  How to propose changes
├── CODE_OF_CONDUCT.md
└── LICENSE          Apache License 2.0
```

Source and test directories will be added at milestone M1 (foundation: schema, row-level
security, auth, audit logging, CI).

## Contributing

Contributions are welcome — including from people who do not write code. Field experience,
agronomic review, translation, and documentation matter as much as commits here.

Two rules carry weight in this repository:

- **Cite your sources.** Any figure a user might act on links back to where it came from.
  This is a process rule, not a norm, because the numbers affect livelihoods.
- **Don't hard-code one region's assumptions as the default.** Crops, units, seasons, and
  regulations differ everywhere.

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

Licensed under the Apache License, Version 2.0. See [`LICENSE`](LICENSE).
