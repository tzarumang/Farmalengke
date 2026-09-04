# Farmalengke — Product Requirements Document

_Version 0.1 draft · Prepared by Innovhub · Client approver: [NEEDS INPUT] · Date: 2026-09-04_

> **Draft status.** This PRD is a working draft, not a baseline. Four scoping decisions
> have been confirmed with the client (business model, forward-contract scope, vault
> custody, target market); everything still marked `[NEEDS INPUT]` in §14 must be closed
> before the client can sign Gate 5 and set baseline v1.0.

---

## 1. Overview & Objective

Farmalengke is a Philippine agricultural trading platform that connects smallholder
farmers to buyers through both a physical consolidation point (the *bagsakan*, or trading
port) and a digital equivalent. It operates as a **principal buyer** — purchasing produce
outright at agreed prices and carrying inventory risk — and simultaneously as a
**marketplace**, where third-party buyers transact directly with farmers for a commission.
Around that trading core sit three supporting capabilities: a logistics network of
freelance and small-fleet delivery providers, a predictive analytics tool that forecasts
yield and price to support planting and forward-contracting decisions, and a Vault that
holds prepayment and funding as a Stellar-based stablecoin balance governed by a Soroban
smart contract.

**Objective:** increase the share of the final selling price that reaches the farmer,
while giving buyers dependable volume and quality — measured by farmgate price realization
and fulfilment reliability, per the KPIs in §5.

## 2. Background & Context

Philippine agricultural supply chains are characterised by long trader chains between
farm and market. Produce typically passes through several intermediaries, each taking
margin, and smallholders — who lack storage, transport, price information, and
pre-harvest liquidity — have weak bargaining power at the point of sale. The *bagsakan*
already exists as an institution: a physical drop-off and consolidation point where
farmers deliver and traders buy.

Farmalengke's premise is that digitising the bagsakan — rather than replacing it — is the
realistic intervention. Farmers keep a physical place to deliver, while the platform adds
price transparency, guaranteed offtake, forward commitments, and pre-harvest cash.

**Why now.** Mobile penetration and digital wallet adoption (GCash, Maya) are now high
enough among rural Philippine users to make a digital settlement layer viable, which was
not true a decade ago.

> **Evidence gap.** The paragraphs above describe the problem as understood from the
> client brief. The specific market sizing, current trader-margin percentages, and
> adoption figures that would justify the investment case are **not yet sourced**. See
> `[NEEDS INPUT] Q1` and `Q2` in §14 — these must be evidenced before Gate 2, not assumed.

**Constraints envelope.** Budget: `[NEEDS INPUT] Q3`. Timeline: `[NEEDS INPUT] Q4`.
Technology stack is fixed by the client (§10). Target market is the Philippines first,
with architecture prepared for later multi-jurisdiction expansion.

## 3. Problem Statement

**Job to be done — farmer:** *"When my crop is ready, I need to convert it to cash quickly
and at a fair price, without losing it to spoilage or being forced to accept whatever the
buyer at the bagsakan offers me that morning."*

**Job to be done — buyer:** *"I need a reliable volume of produce at a known quality and a
known price, on a date I can plan around."*

**Pain points**

| Who | Pain |
|-----|------|
| Farmer | No visibility into prevailing prices; accepts the price offered on the day |
| Farmer | No pre-harvest liquidity; borrows from traders at unfavourable terms, often repaid in produce |
| Farmer | Post-harvest loss when produce cannot be moved or sold in time |
| Farmer | No forward certainty — plants without knowing whether there will be a buyer |
| Buyer | Inconsistent volume and quality; no way to plan supply |
| Buyer | No recourse when a supplier fails to deliver |
| Logistics | Fragmented, informal, unpredictable trips and payment |

**Current workarounds.** Farmers sell to whichever trader appears; rely on informal credit
from those same traders; use text messages and personal networks for price discovery.
Buyers maintain their own trader relationships. None of this is recorded, which is why
neither side can build a track record that would earn better terms.

## 4. Users & Personas

| Persona | Role / permissions | Volume (target, to be validated — `[NEEDS INPUT] Q5`) | Goals |
|---------|--------------------|--------|-------|
| **Smallholder farmer** | Own profile, own listings, own contracts, own Vault balance. Cannot see others' prices beyond published market rates | 500 in year 1 | Sell at a fair price, get paid fast, access pre-harvest cash |
| **Farmer group / cooperative** | All farmer permissions, plus aggregate listing on behalf of member farmers and view of member deliveries | 10 groups | Consolidate member volume for better terms |
| **Bagsakan operator** | Record intake, grade and weigh produce, confirm receipt, manage physical inventory at one site | 2 sites | Move produce through the port accurately and fast |
| **Buyer (wholesaler, institutional, processor)** | Browse listings, place orders, enter forward contracts, view own order history | 50 | Reliable volume, known quality, planned delivery |
| **Logistics provider (freelance rider / small fleet)** | Accept delivery jobs, update status, upload proof of delivery, view own earnings | 30 | Steady jobs and prompt payment |
| **Platform trading desk** | Set buy prices, accept/decline produce, manage platform-owned inventory and positions | 3 staff | Trade profitably without over-committing capital |
| **Treasury / finance admin** | Vault operations, reconciliation, payout approval, cash-out rails. Dual-control on movements | 2 staff | Funds correct, reconciled, auditable |
| **Compliance officer** | KYC review, AML alerts, audit log access. Read-only on trading | 1 staff | Meet regulatory obligations, evidence them |
| **Platform administrator** | User management, role assignment, configuration. No unilateral fund movement | 2 staff | Keep the platform running safely |

**Permissions principle.** No single role can both initiate and approve a movement of
funds. Trading desk sets prices but cannot release Vault funds; treasury releases funds
but cannot set prices. This separation is a requirement, not an implementation detail
(FR-27, FR-28).

## 5. Goals & Success Metrics

| ID | Goal | Success metric (KPI) |
|----|------|----------------------|
| **G1** | Raise the share of final sale price reaching the farmer | Farmgate price realization rises 15% against a baseline measured in the first 60 days of operation, by month 12 |
| **G2** | Reduce post-harvest loss on produce moving through the platform | Spoilage and rejection below 5% of transacted volume by weight, by month 12 |
| **G3** | Give buyers dependable supply | 95% of confirmed orders fulfilled in full, on the agreed date, at the agreed grade, by month 12 |
| **G4** | Give farmers pre-harvest liquidity | 200 farmers receive at least 1 prepayment; default rate below 8% of disbursed value, by month 12 |
| **G5** | Improve planting and pricing decisions | Price forecast mean absolute percentage error below 20% at a 14-day horizon, on the top 5 commodities by volume |
| **G6** | Establish viable platform unit economics | Platform gross margin per transacted kilo turns positive by month 9, sustained 3 consecutive months |
| **G7** | Operate lawfully in the Philippines | Zero regulatory findings; required registrations and licences in place before the first peso of public funds is held |

> G7 is deliberately a first-class goal, not a compliance footnote. The Vault holds
> customer money; operating it without the correct licence is an existential risk to the
> whole platform, not a feature defect. See RISK-1 and RISK-2 in §12.

## 6. Scope & MVP

**MoSCoW**

- **Must:** Farmer signup and KYC; produce listing; bagsakan intake with grading and
  weighing; platform principal purchase; marketplace listing and order placement; order
  fulfilment and delivery tracking; logistics provider signup and job assignment; Vault
  balance, prepayment disbursement and settlement; payout to Philippine cash-out rails;
  audit logging; role-based access control; Filipino and English interface.
- **Should:** Forward contracts between buyer and farmer; farmer credit scoring from
  delivery history; yield forecasting; price forecasting; cooperative/group accounts;
  buyer ratings; dispute resolution workflow; offline-tolerant field data capture.
- **Could:** Multi-bagsakan inventory transfer; produce quality photo capture with
  automated grading assistance; buyer subscriptions/standing orders; SMS-only interaction
  for farmers without smartphones; logistics route optimisation.
- **Won't (now):** Tradable derivatives or price speculation by non-participants;
  secondary trading of forward contracts; consumer/retail direct-to-household sales;
  farm input (seed, fertiliser) marketplace; equipment leasing; crop insurance
  underwriting; expansion beyond the Philippines.

**The MVP boundary.** MVP is a *single bagsakan site, single region, five commodities*,
operating the principal-buyer model end to end — farmer signs up, lists produce, delivers
to the bagsakan, is graded and weighed, is paid from the Vault, and the platform resells
to a buyer who ordered through the marketplace. Logistics is included but may be
manually dispatched. Analytics ships as descriptive reporting only in MVP; forecasting
follows once there is transaction history to train on.

**Explicitly out of scope**

1. Any instrument tradable by a party who does not intend to take or make delivery. The
   client confirmed forward contracts are commercial supply agreements, not financial
   products; the platform must not become a derivatives venue by accident.
2. Secondary-market resale of forward contracts (same reason).
3. Lending to farmers as a standalone product. Prepayment is advance consideration
   against a specific committed delivery, not a general-purpose loan — this distinction
   is material to whether a lending licence is required, and must be confirmed by counsel
   (`[NEEDS INPUT] Q6`).
4. Custody of customer crypto assets other than the single stablecoin used for settlement.
5. Non-Philippine jurisdictions in MVP, though the data model must not preclude them.
6. Native mobile applications in MVP — the platform ships as a responsive web application.

## 7. Functional Requirements

_Each story carries acceptance criteria and the goal `(G#)` it serves._

### 7.1 Farmer signup & identity

- **FR-1 (G1)** — **As a** smallholder farmer **I want** to register with my mobile number
  and a one-time PIN **so that** I can join without an email address or a computer.
  - _Acceptance criteria:_ Registration completes with mobile number + OTP only; no email
    required; OTP expires after 5 minutes; 3 failed OTP attempts locks the number for 15
    minutes; the flow completes in under 2 minutes on a 3G connection; interface available
    in Filipino and English.
- **FR-2 (G7)** — **As a** compliance officer **I want** each farmer to complete
  identity verification proportionate to their transaction value **so that** the platform
  meets its KYC obligations without excluding farmers who lack formal documents.
  - _Acceptance criteria:_ Tiered KYC — Tier 1 (name, mobile, barangay, photo) permits
    transactions up to a configurable ceiling; Tier 2 (government ID + selfie match)
    required above it; specific thresholds set from the legal opinion in `Q6`; a farmer
    blocked at a tier boundary sees what document is needed and why; all verification
    decisions are timestamped and attributable to a named reviewer.
- **FR-3 (G1)** — **As a** farmer **I want** to register my farm — location, area, and the
  crops I grow **so that** buyers and the platform know what I can supply.
  - _Acceptance criteria:_ Farm captures GPS point or barangay selection, area with unit
    (hectare or square metre), and one or more crops with expected harvest months;
    location capture works offline and syncs later; a farmer may register multiple farms.
- **FR-4 (G1)** — **As a** cooperative officer **I want** to register my group and link
  member farmers **so that** we can sell consolidated volume.
  - _Acceptance criteria:_ A group has a named officer; farmers join by invitation and
    must accept; a member can leave; group listings show constituent member contributions;
    a farmer's individual identity and Vault balance stay separate from the group's.

### 7.2 Produce listing & the digital trading port

- **FR-5 (G1)** — **As a** farmer **I want** to list produce I have or expect to have
  **so that** the platform or a buyer can purchase it.
  - _Acceptance criteria:_ A listing captures commodity, variety, quantity with unit,
    quality grade claimed, harvest or availability date, and location; a listing is either
    *available now* or *expected* with a date; listings can be created offline and sync on
    reconnection; a farmer can edit or withdraw a listing until it is committed to an order.
- **FR-6 (G1)** — **As a** farmer **I want** to see the current platform buying price and
  recent market prices for my commodity **so that** I can judge whether to sell now.
  - _Acceptance criteria:_ Price view shows the platform's current bid, the 7-day price
    range, and the source and timestamp of each figure; no price is displayed without its
    source; prices older than 48 hours are visibly marked stale.
- **FR-7 (G3)** — **As a** buyer **I want** to browse and filter available produce **so
  that** I can find the volume and quality I need.
  - _Acceptance criteria:_ Filter by commodity, grade, quantity, location, and
    availability date; results show quantity, grade, distance, and earliest delivery date;
    a buyer sees only listings they are eligible to purchase.
- **FR-8 (G3)** — **As a** buyer **I want** to place an order against one or more listings
  **so that** I can secure supply.
  - _Acceptance criteria:_ An order aggregates one or more listings; placing it reserves
    the quantity and prevents double-selling; the order states total price, delivery date,
    and delivery location; the farmer is notified and must confirm within a configurable
    window (default 24 hours) or the reservation lapses.
- **FR-9 (G6)** — **As the** platform trading desk **I want** to set and publish buying
  prices per commodity and grade **so that** the platform buys at a margin it controls.
  - _Acceptance criteria:_ Prices set per commodity, grade, and bagsakan site, with an
    effective-from timestamp; a price change never retroactively alters a committed order;
    every price change is logged with the user who made it; prices can be scheduled ahead.

### 7.3 Forward contracts

- **FR-10 (G1, G3)** — **As a** buyer **I want** to commit now to purchase a future
  harvest at an agreed price **so that** I secure supply and the farmer gets certainty.
  - _Acceptance criteria:_ A contract records commodity, grade, quantity, agreed unit
    price, delivery window, delivery location, and both parties' acceptance; both parties
    must accept explicitly; the accepted terms are immutable thereafter and any variation
    creates a new linked version; the contract is presented in plain Filipino and English
    before acceptance.
- **FR-11 (G4)** — **As a** farmer **I want** part of a forward contract's value advanced
  to me at signing **so that** I can fund inputs for the season.
  - _Acceptance criteria:_ Advance is a configurable percentage of contract value, capped
    per farmer by credit limit (FR-13); advance is disbursed from the Vault only after
    both parties accept and the buyer's funds are committed; the advance is recorded as a
    liability against the contract and is netted at settlement.
- **FR-12 (G3)** — **As a** party to a forward contract **I want** clearly defined
  consequences if delivery falls short **so that** I know my exposure before I sign.
  - _Acceptance criteria:_ Shortfall handling is stated in the contract terms before
    acceptance; the system computes settlement for full, partial, and zero delivery;
    a shortfall opens a dispute case (FR-24) rather than silently deducting; force-majeure
    conditions (typhoon, flood, pest declaration) are recorded as a distinct outcome from
    ordinary default and do not count toward the farmer's default rate.

> **Design note.** FR-12's force-majeure carve-out matters for G4's default-rate KPI. In
> a typhoon-exposed country, treating weather loss as farmer default would both misstate
> the metric and penalise farmers for events outside their control.

### 7.4 Bagsakan (trading port) operations

- **FR-13 (G2)** — **As a** bagsakan operator **I want** to record produce arriving at the
  port against the farmer and the expected listing or contract **so that** intake is
  attributed correctly.
  - _Acceptance criteria:_ Intake records farmer, commodity, gross and net weight, grade
    assessed, arrival timestamp, and operator identity; intake can be matched to an
    existing listing, order, or contract, or recorded as a walk-in; intake works offline
    and syncs on reconnection with conflicts surfaced for human resolution, never
    silently merged.
- **FR-14 (G2)** — **As a** bagsakan operator **I want** to grade and weigh produce with
  the farmer present and record their agreement **so that** disputes about grade are
  prevented rather than argued afterwards.
  - _Acceptance criteria:_ Grade assessment records the grading standard applied, the
    grade assigned, the weight, and the operator; the farmer confirms on the device or
    the disagreement is recorded; a photograph of the delivered lot is captured and stored
    against the intake record; the farmer receives a receipt by SMS or in-app within 60
    seconds of confirmation.
- **FR-15 (G2)** — **As a** bagsakan operator **I want** to track produce held at the site
  **so that** we know what is on hand and how long it has been there.
  - _Acceptance criteria:_ Inventory shows quantity by commodity and grade, age since
    intake, and assigned order if any; lots exceeding a per-commodity age threshold are
    flagged; every movement (in, out, transferred, written off) is logged with a reason
    and a user.
- **FR-16 (G2)** — **As the** trading desk **I want** to record spoilage and rejection
  **so that** loss is measured rather than absorbed invisibly.
  - _Acceptance criteria:_ Write-off records quantity, reason, and responsible stage;
    write-offs are reportable against G2's 5% target; a write-off above a configurable
    value requires second-person approval.

### 7.5 Logistics

- **FR-17 (G3)** — **As a** delivery provider **I want** to register with my vehicle and
  capacity **so that** I receive jobs I can actually do.
  - _Acceptance criteria:_ Registration captures identity, vehicle type, capacity in
    kilograms, whether refrigerated, licence and insurance where required, and service
    area; documents are verified before the first job is assigned; expiry dates are
    tracked and a provider with a lapsed document stops receiving jobs.
- **FR-18 (G3)** — **As a** delivery provider **I want** to see and accept available jobs
  **so that** I can plan my day.
  - _Acceptance criteria:_ Job shows pickup, destination, commodity, weight, required
    vehicle type, time window, and payment amount before acceptance; acceptance is
    first-come or assigned per configuration; an accepted job is removed from other
    providers' views; a provider can decline without penalty before acceptance.
- **FR-19 (G3)** — **As a** buyer **I want** to see where my delivery is **so that** I can
  plan receiving.
  - _Acceptance criteria:_ Status transitions (assigned, collected, in transit, delivered,
    failed) are visible with timestamps; each transition is attributable to a user or
    device; location updates where the provider has granted permission; a failed delivery
    requires a recorded reason.
- **FR-20 (G3)** — **As a** delivery provider **I want** proof of delivery captured **so
  that** my payment is not disputed later.
  - _Acceptance criteria:_ Proof captures recipient name, signature or photograph, and
    timestamp; proof is captured offline and syncs; payment is released against confirmed
    proof per FR-26.

### 7.6 Predictive analytics

- **FR-21 (G5)** — **As a** farmer **I want** an indicative price forecast for my
  commodity **so that** I can decide when to sell or whether to commit forward.
  - _Acceptance criteria:_ Forecast presents a range, not a point estimate; every forecast
    shows its confidence interval, the data it used, and its recent accuracy; where data is
    insufficient the tool states that instead of producing a number; forecasts are never
    presented as advice or a guarantee.
- **FR-22 (G5)** — **As the** trading desk **I want** yield and volume forecasts by region
  and commodity **so that** I can plan buying capacity and working capital.
  - _Acceptance criteria:_ Forecast covers a 30, 60, and 90-day horizon; shows expected
    volume with interval; identifies the top 3 drivers of each forecast; back-tested
    accuracy is published alongside and refreshed monthly.
- **FR-23 (G5)** — **As a** platform administrator **I want** forecast accuracy tracked
  against outcomes **so that** we know whether the tool is working.
  - _Acceptance criteria:_ Every forecast is stored with its inputs and later scored
    against actuals; MAPE is computed per commodity and horizon; accuracy below the G5
    threshold of 20% MAPE at 14 days raises an alert and the forecast is withdrawn from
    the farmer-facing view until it recovers.

> **Sequencing.** FR-21 through FR-23 cannot ship at MVP: there is no transaction history
> to train on at launch. Analytics ships first as descriptive reporting over actual
> platform trades, and forecasting activates only once accuracy clears the G5 bar on
> back-testing. Publishing a forecast that is worse than a farmer's own judgement would
> actively harm the people this platform exists to serve.

### 7.7 Vault, payments & settlement

- **FR-24 (G4)** — **As a** farmer **I want** a Vault balance showing what I am owed, what
  has been advanced, and what I can withdraw **so that** I understand my position.
  - _Acceptance criteria:_ Balance distinguishes available, committed/held, and advanced
    amounts; every movement has a timestamp, counterparty, and reference; balance is
    displayed in Philippine pesos as the primary unit regardless of the underlying
    settlement asset; history is exportable.
- **FR-25 (G4)** — **As a** buyer **I want** my payment held until delivery is confirmed
  **so that** I am not exposed to non-delivery.
  - _Acceptance criteria:_ Funds move to a held state on order confirmation; release is
    triggered only by confirmed delivery (FR-14 or FR-20) or by dispute resolution
    (FR-29); neither party can unilaterally release held funds; the hold and release are
    enforced by the Soroban contract, not by application code alone.
- **FR-26 (G4)** — **As a** farmer or delivery provider **I want** to withdraw my balance
  to a Philippine account or wallet **so that** the money is usable.
  - _Acceptance criteria:_ Cash-out supports at least GCash, Maya, and InstaPay/PESONet
    bank transfer; the fee and the amount received are shown before confirmation; a
    withdrawal request produces a reference number; funds arrive within 1 banking day for
    wallet rails; failures are surfaced with a reason and the balance is restored.
- **FR-27 (G7)** — **As a** treasury administrator **I want** every movement of platform
  funds to require two named approvers **so that** no individual can move money alone.
  - _Acceptance criteria:_ Movements above a configurable threshold require initiation and
    approval by two distinct authenticated users; the same user cannot fill both roles;
    the requirement is enforced by the Soroban contract's multi-signature configuration,
    not solely in the application layer; every approval is logged immutably.
- **FR-28 (G7)** — **As a** compliance officer **I want** an immutable audit trail of
  every fund movement, KYC decision, and price change **so that** we can evidence
  compliance.
  - _Acceptance criteria:_ Audit records are append-only and cannot be edited or deleted
    by any role including administrators; each record carries actor, action, timestamp,
    and before/after state; the trail is exportable for a named date range; on-chain
    settlement events are reconcilable to off-chain records with a documented procedure.
- **FR-29 (G3)** — **As** either party to a transaction **I want** to raise a dispute and
  have held funds frozen until it is resolved **so that** neither side can be defrauded.
  - _Acceptance criteria:_ Raising a dispute freezes the associated held funds; both
    parties can submit evidence including photographs; a named platform adjudicator
    resolves with a recorded reason; resolution outcomes (release, partial release,
    refund) are executed through the Vault; first response within 2 business days.
- **FR-30 (G7)** — **As a** treasury administrator **I want** daily reconciliation between
  on-chain Vault state and off-chain ledger **so that** discrepancies are caught within
  one day rather than at audit.
  - _Acceptance criteria:_ Reconciliation runs at least once every 24 hours; any
    discrepancy raises an alert to treasury and compliance within 15 minutes of detection;
    unreconciled discrepancies block new prepayment disbursement until cleared.

### 7.8 Cross-cutting workflows and edge cases

- **FR-31 (G1)** — **As a** farmer with a basic phone and no reliable data connection
  **I want** to transact **so that** connectivity does not exclude me.
  - _Acceptance criteria:_ Core farmer flows (view price, confirm intake, check balance)
    are reachable by SMS or USSD, or via an operator acting on the farmer's behalf at the
    bagsakan with the farmer's recorded consent; the fallback path is tested as a
    first-class flow, not a degraded one.
- **FR-32 (G2)** — **As the** system **I want** to handle the case where delivered
  quantity or grade differs from what was ordered **so that** partial deliveries settle
  correctly.
  - _Acceptance criteria:_ Settlement recomputes on actual delivered weight and assessed
    grade; the buyer is notified and must accept the variance or open a dispute; variance
    beyond a configurable tolerance requires explicit buyer acceptance before release.
- **FR-33 (G7)** — **As the** system **I want** to behave safely when the Stellar network
  or the stablecoin issuer is unavailable **so that** users are not left in an
  indeterminate state.
  - _Acceptance criteria:_ Vault operations fail closed — an operation that cannot be
    confirmed on-chain is never reported as successful; pending operations are queued and
    reconciled; users see an honest status rather than an optimistic one; the platform can
    continue accepting non-financial operations (listing, intake, delivery) while
    settlement is degraded.

## 8. Non-Functional Requirements

_Targets below are engineering proposals derived from the personas and volumes in §4.
They are **our** numbers, not the client's, and must be confirmed at Gate 3
(`[NEEDS INPUT] Q7`)._

| Area | Requirement (with a number) | Goal |
|------|-----------------------------|------|
| Performance — farmer views | Price view and Vault balance render within 2 seconds on a 3G connection at the 95th percentile | G1, G4 |
| Performance — search | Buyer listing search returns within 1 second at the 95th percentile for up to 10,000 active listings | G3 |
| Performance — intake | Bagsakan intake record saves locally within 500 milliseconds, independent of network state | G2 |
| Payload budget | Farmer-facing initial page load under 300 KB compressed, to keep cost on metered data below 1 peso per session | G1 |
| Availability — trading | 99.5% monthly uptime for listing, ordering, and intake, measured excluding scheduled maintenance of at most 4 hours per month | G3 |
| Availability — Vault | 99.9% monthly uptime for balance reads; settlement writes may degrade but must fail closed per FR-33 | G4, G7 |
| Scale — year 1 | 500 farmers, 50 buyers, 30 logistics providers, 2 bagsakan sites, 200 transactions per day, sustained | G6 |
| Scale — headroom | Architecture supports 10x year-1 volume (5,000 farmers, 2,000 transactions per day) without redesign | G6 |
| Concurrency | 200 concurrent authenticated sessions with no degradation beyond the stated 95th-percentile latency targets | G3 |
| Throughput — settlement | At least 500 Vault settlement operations per hour at peak harvest | G4 |
| Response time — disputes | First human response to a raised dispute within 2 business days | G3 |
| Data durability | Zero tolerance for lost financial records; point-in-time recovery to any moment in the preceding 30 days | G7 |
| Recovery | RPO 15 minutes, RTO 4 hours for the trading platform; RPO 0 for Vault state, which is reconstructable from on-chain history | G7 |
| Security — authentication | Multi-factor required for all staff roles; session timeout 15 minutes for treasury and compliance roles, 12 hours for farmers | G7 |
| Security — authorization | Row-level security enforced in the database for every table holding user data; no table relies on application code alone for access control | G7 |
| Security — encryption | TLS 1.3 in transit; AES-256 at rest; no private key material in application code, environment files, or version control at any time | G7 |
| Security — key custody | Vault signing keys held in a hardware security module or equivalent, with 2-of-3 multi-signature for treasury movements | G7 |
| Security — testing | Independent penetration test of the Vault and settlement path passed before holding any public funds; zero unresolved high or critical findings | G7 |
| Privacy / compliance | Philippine Data Privacy Act (RA 10173) compliance including NPC registration; GDPR-equivalent data subject rights implemented from day 1 to avoid rework at expansion | G7 |
| Privacy — data minimisation | Farmer location stored at barangay granularity by default; GPS point captured only with explicit per-farm consent and retained 24 months | G7 |
| AML / financial crime | Transaction monitoring with alerting on configurable thresholds; sanctions screening at onboarding and rescreened at least every 90 days | G7 |
| Accessibility | WCAG 2.2 Level AA for all farmer- and buyer-facing screens; minimum touch target 44 by 44 pixels; usable at 200% zoom | G1 |
| Accessibility — literacy | Farmer-facing copy at a reading level appropriate to 6 years of formal schooling; every monetary action confirmable from an icon and number alone | G1 |
| Localization | Filipino and English at launch, with the string layer supporting at least 3 further languages (Cebuano, Ilocano, Hiligaynon) without code change | G1 |
| Localization — units | Metric primary, with local trade units (kaban, sako) displayed alongside and configurable per commodity per region | G1 |
| Device support | Functional on Android 9 and later, on devices with 2 GB RAM, on a 3G connection | G1 |
| Observability | Structured logging, metrics, and alerting on all financial paths; alert to on-call within 5 minutes of a settlement failure | G7 |
| Auditability | Every financial record retained a minimum of 10 years, per Philippine record-keeping expectations, subject to confirmation in Q6 | G7 |

## 9. Data Requirements

| Entity | Source | Sensitivity / classification | Retention | Owner |
|--------|--------|------------------------------|-----------|-------|
| Farmer profile | Farmer at signup | **Personal / sensitive** — name, mobile, address, government ID | Active + 10 years (financial record) | Farmer, processed by platform |
| KYC documents & selfie | Farmer at verification | **Highly sensitive** — biometric and identity documents | 5 years after relationship ends, then destroyed | Farmer |
| Farm record | Farmer | **Personal** — GPS location reveals residence | 24 months for GPS; barangay indefinitely | Farmer |
| Produce listing | Farmer | **Commercial, low** | Active + 3 years | Farmer |
| Intake / grading record | Bagsakan operator | **Commercial, medium** — basis for payment | 10 years | Platform |
| Order & contract | Buyer + farmer | **Commercial, high** — legally binding | 10 years | Both parties |
| Forward contract terms | Both parties | **Commercial, high** — immutable once accepted | 10 years | Both parties |
| Vault ledger entry | Platform + chain | **Financial, high** | 10 years, immutable | Platform (regulated) |
| On-chain settlement record | Stellar network | **Public by nature** — must contain no personal data | Permanent, outside platform control | Public ledger |
| Payout / cash-out record | Payment rail | **Financial, high** — includes bank/wallet identifiers | 10 years | Platform |
| Logistics provider profile | Provider | **Personal** — identity, licence, insurance | Active + 5 years | Provider |
| Delivery record & proof | Provider | **Commercial, medium** — may contain a signature image | 3 years | Platform |
| Dispute case & evidence | Parties | **Commercial + personal** | 10 years | Platform |
| Price observation | Platform + external | **Public / low** | Indefinite | Platform |
| Forecast & its inputs | Analytics | **Commercial, medium** | Indefinite (needed for accuracy scoring) | Platform |
| Audit log | System | **High** — append-only | 10 years, immutable | Platform |

**Critical data rule.** No personal data is ever written on-chain. The Stellar ledger is
public and permanent; a national ID number or phone number placed there cannot be
retracted and would be an irreversible Data Privacy Act breach. On-chain records carry
opaque identifiers only, resolved to people through the off-chain database.

**Data ownership.** Farmers own their production and transaction history. A farmer who
leaves may export it and request erasure of everything not required by financial
record-keeping law. This is a product commitment, not merely a legal one — a platform
that traps a farmer's track record recreates the dependency it exists to break.

## 10. Integrations & Dependencies

**Fixed technology stack** (client-specified, not open for redesign):

| Layer | Technology | Notes |
|-------|-----------|-------|
| Frontend & API | Next.js (App Router) with TypeScript | Responsive web; server components for low-bandwidth rendering |
| Database, auth, storage | Supabase, **self-hosted** | Self-hosting is a client requirement — it implies the team owns Postgres operations, backups, and upgrades |
| Vault settlement | Stellar, with a Soroban smart contract | Holds escrow, enforces multi-signature release |
| Settlement asset | A Stellar-issued stablecoin | Specific asset and issuer `[NEEDS INPUT] Q8` |

**External integrations**

| Integration | Purpose | Risk if unavailable |
|-------------|---------|---------------------|
| GCash / Maya | Farmer and provider cash-out | Farmers cannot access funds — critical |
| InstaPay / PESONet | Bank transfers | Degrades to wallet-only cash-out |
| SMS gateway | OTP, receipts, notifications for basic phones | Signup and FR-31 blocked — critical |
| Stellar network + Horizon/RPC | Settlement | Fail closed per FR-33 |
| Stablecoin issuer | Value stability, redemption | **Single point of failure — see RISK-3** |
| Weather data service | Yield forecasting inputs | Forecast quality degrades; not critical at MVP |
| Market price sources (DA, trading posts) | Price benchmarks for FR-6 | Price display loses its comparison baseline |
| Sanctions / PEP screening | AML obligation | Onboarding blocked for compliance reasons |

**Dependencies and migration.** There is no existing system to migrate from; the
repository currently holds only scaffolding. Where farmers or bagsakan operators keep
paper or spreadsheet records, a one-off import path is a *Should*, not a *Must*.

## 11. UX / Design & Brand

**Design references and brand.** `[NEEDS INPUT] Q9` — no brand guidelines, logo, or
palette exist yet. If none are supplied, the recommendation is to run the brand
guidelines process before UI build begins, so the interface is not styled twice.

**Design principles**, which follow from the users rather than from taste:

1. **Money is always legible.** Amounts in pesos, large, with the direction of movement
   unmistakable. A farmer must never be uncertain whether they are receiving or paying.
2. **Nothing hidden behind literacy.** Every critical action is expressible in an icon and
   a number. Text supports the interface; it is not the only route through it.
3. **The network is assumed hostile.** Every screen has a defined state for offline,
   slow, and stale data. "Loading" forever is a defect.
4. **Irreversible actions look irreversible.** Accepting a forward contract or confirming
   a grade is visually distinct from browsing, and states the consequence before the tap.
5. **The physical and the digital agree.** What the bagsakan operator's screen says must
   match the paper receipt in the farmer's hand, or trust in the platform collapses.

**Accessibility target.** WCAG 2.2 Level AA, tested on a low-end Android device on a
throttled 3G connection — not only in a desktop browser.

## 12. Assumptions, Constraints & Risks

**Assumptions** (each is a belief that, if wrong, changes the plan)

1. Farmers in the target region have access to an Android smartphone, their own or a
   household member's. **If wrong**, FR-31's SMS/USSD path becomes a *Must* at MVP and the
   scope grows materially.
2. A licensed cash-out partner will onboard the platform. **If wrong**, farmers cannot
   convert Vault balances to spendable money and the product does not function.
3. The platform can obtain the licences implied by holding customer funds. **If wrong**,
   the Vault must be redesigned around a licensed third party — see RISK-1.
4. Bagsakan operators can be trained to grade consistently. **If wrong**, G2 and G3 are
   both unreachable, since every settlement rests on the grade.
5. Sufficient transaction history to train forecasts accumulates within 12 months. **If
   wrong**, FR-21 through FR-23 slip beyond year 1.

**Constraints**

- Technology stack is fixed (§10), including self-hosted Supabase.
- Philippine market first; architecture must not preclude other jurisdictions.
- Budget and timeline: `[NEEDS INPUT] Q3, Q4`.
- The platform carries inventory and price risk as principal buyer, so working capital is
  a hard operating constraint, not only a funding question.

**Risk log**

| # | Risk | Impact | Likelihood | Mitigation | Owner |
|---|------|--------|------------|------------|-------|
| **RISK-1** | Holding customer funds as a platform-custodied stablecoin likely requires BSP Virtual Asset Service Provider registration and possibly e-money authority. Operating without it risks cease-and-desist and personal liability | **H — existential** | **H** | Obtain written legal opinion **before any code touches customer funds** (Q6); design the Vault so a licensed third-party custodian can be substituted without redesigning the trading platform | Client sponsor |
| **RISK-2** | Prepayment against future harvest may be characterised as lending, triggering a separate licence | H | M | Same legal opinion (Q6); structure advances strictly as consideration under a delivery contract, never as standalone credit | Client sponsor |
| **RISK-3** | Stablecoin issuer failure, depeg, or freeze would strand farmer balances in an asset they never chose to hold | **H** | M | Hold the shortest possible duration in the asset; sweep to fiat on a defined schedule; select an issuer with attested reserves; define an exit procedure before launch | Treasury |
| **RISK-4** | Farmers bear currency and technology risk they did not consent to and may not understand | **H — ethical** | M | Denominate and display everything in pesos; the stablecoin is settlement plumbing the farmer never has to reason about; disclose in plain Filipino | Product |
| **RISK-5** | Self-hosted Supabase makes the team responsible for Postgres operations, backup, patching, and uptime | M | H | Budget dedicated operations capacity from day 1; document runbooks; test restore monthly, not merely configure backups | Engineering |
| **RISK-6** | Principal-buyer model consumes working capital and concentrates price risk on the platform | H | H | Position limits per commodity; start marketplace-heavy and grow the principal book only as capital allows; daily mark-to-market | Trading desk |
| **RISK-7** | Forward contracts could be construed as regulated derivatives if any resale or speculation emerges | H | L | Enforce non-transferability in the contract and in code; monitor for proxy trading; §6 out-of-scope items 1 and 2 are load-bearing controls, not preferences | Compliance |
| **RISK-8** | Grading disputes at the bagsakan undermine trust in the platform | M | H | Photograph every lot; farmer confirmation at grading (FR-14); published grading standard; dispute path (FR-29) | Operations |
| **RISK-9** | Forecasts that are wrong could cause farmers real financial loss if acted upon | **H — ethical** | M | Never publish a forecast that fails the G5 accuracy bar (FR-23); always show intervals and accuracy history; never phrase output as advice | Product |
| **RISK-10** | Smart contract defect could lock or lose funds irreversibly | **H** | M | Independent audit before mainnet; testnet soak; upgrade/pause mechanism with multi-signature governance; cap total value held during the initial period | Engineering |
| **RISK-11** | Two-sided marketplace cold start — neither farmers nor buyers join first | H | H | Principal-buyer model directly mitigates this: the platform is the guaranteed first buyer, so farmers need not wait for demand to appear | Commercial |
| **RISK-12** | Platform competes with existing traders who may respond by undercutting or pressuring farmers | M | M | Focus on the services traders do not offer (forward certainty, recorded history, transparent grading); consider partnering with traders as buyers rather than displacing them | Commercial |

## 13. Timeline & Milestones

Durations are **relative** — no absolute dates can be set until the budget and start date
in Q3 and Q4 are known. Sequencing, however, is not arbitrary: the gates below are ordered
by dependency, and M0 genuinely blocks everything financial.

| Milestone | Content | Depends on |
|-----------|---------|-----------|
| **M0 — Legal & compliance gate** | Written legal opinion on custody, prepayment, and forward contracts (Q6); licence path agreed; stablecoin and cash-out partners selected | Nothing — starts immediately, runs parallel to M1 |
| **M1 — Foundation** | Repository, environments, self-hosted Supabase, schema with row-level security, auth, roles, audit logging, CI | — |
| **M2 — Farmer & listing** | FR-1 to FR-9: signup, KYC tiers, farm records, listings, price display, buyer browse and order | M1 |
| **M3 — Bagsakan operations** | FR-13 to FR-16: intake, grading, inventory, write-off, offline capture and sync | M1, M2 |
| **M4 — Vault (testnet)** | FR-24 to FR-30 on Stellar testnet: Soroban contract, escrow, multi-signature, reconciliation. **No real funds** | M1, **M0** |
| **M5 — Logistics** | FR-17 to FR-20: provider onboarding, job assignment, tracking, proof of delivery | M2, M3 |
| **M6 — Security & audit** | Independent smart-contract audit; penetration test; remediation to zero high and critical findings | M4, M5 |
| **M7 — Pilot (one bagsakan)** | Live with a limited farmer cohort, real money, capped exposure. Forward contracts (FR-10 to FR-12) enabled here | **M0 licences in hand**, M6 |
| **M8 — Analytics** | FR-21 to FR-23: descriptive reporting first; forecasting activates only on passing the G5 accuracy bar | 6+ months of M7 transaction history |
| **M9 — Scale** | Second bagsakan site, wider commodity range, cooperative accounts | M7 proven against G1, G2, G3 |

**The critical path runs through M0, not through engineering.** Building the Vault before
the legal position is settled risks writing a system that cannot lawfully be operated.

## 14. Open Questions

| # | Question | Owner | Blocks |
|---|----------|-------|--------|
| **Q1** | `[NEEDS INPUT]` What is the current trader margin between farmgate and wholesale for the target commodities, and what is the source? G1's "15% improvement" needs a measured baseline | Client | Gate 2 |
| **Q2** | `[NEEDS INPUT]` Market sizing: how many farmers, what volume, in the target region? | Client | Gate 2 |
| **Q3** | `[NEEDS INPUT]` Budget envelope, including the working capital required for the principal-buyer book | Client | Gate 4 |
| **Q4** | `[NEEDS INPUT]` Target launch date and any fixed external deadline (grant, season, investor) | Client | Gate 4 |
| **Q5** | `[NEEDS INPUT]` Are the year-1 volumes in §4 the client's actual targets, or placeholders? | Client | Gate 3 |
| **Q6** | `[NEEDS INPUT]` **Legal opinion** — does platform-custodied stablecoin require BSP VASP registration or e-money authority? Is prepayment lending? Are forward contracts commercial supply or regulated instruments? What are the record-retention obligations? | Client + counsel | **M0, and all of M4/M7** |
| **Q7** | `[NEEDS INPUT]` Confirm or revise the §8 non-functional targets — they are our proposals, not the client's | Client | Gate 3 |
| **Q8** | `[NEEDS INPUT]` Which stablecoin and issuer? What is the redemption path to pesos? | Client + treasury | M4 |
| **Q9** | `[NEEDS INPUT]` Brand guidelines, logo, palette — do these exist, or should they be created first? | Client | M2 |
| **Q10** | `[NEEDS INPUT]` Which region and which 5 commodities for the MVP? | Client | Gate 3, M2 |
| **Q11** | `[NEEDS INPUT]` Which grading standard applies per commodity — a DA standard, a trade convention, or platform-defined? | Client + operations | M3 |
| **Q12** | `[NEEDS INPUT]` Who is the named approver with authority to baseline this PRD, and who signs each gate? | Client | **Gate 1** |
| **Q13** | `[NEEDS INPUT]` Does the platform hold produce on consignment as well as buying outright? This changes revenue recognition and risk | Client | Gate 3 |
| **Q14** | `[NEEDS INPUT]` What happens to a farmer's advance if the harvest fails entirely through no fault of theirs? Confirm the policy behind FR-12's force-majeure handling | Client | Gate 3 |
| **Q15** | `[NEEDS INPUT]` Is there an existing bagsakan site, operator relationship, or buyer commitment to build the pilot around? | Client | M7 |

## 15. Approvals

_See the sign-off log ([`docs/prd/SIGNOFF-LOG.md`](docs/prd/SIGNOFF-LOG.md)). Baseline v1.0 is set at the Final
PRD approval; change control applies thereafter._

**This PRD is not yet baselined.** Gate 1 cannot be signed until Q12 names the approver,
and Gate 5 cannot be reached while Q6 — the legal opinion governing whether the Vault can
lawfully operate as designed — remains open.
