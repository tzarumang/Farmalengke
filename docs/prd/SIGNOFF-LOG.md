# Sign-Off & Change-Control Log — Farmalengke

Five client sign-offs, one per gate. Each is given by the named client approver, dated.
The author of the PRD does not sign these off.

**Named client approver:** `[NEEDS INPUT] Q12` — no approver has been identified. Gate 1
cannot be signed until this is filled in, because there is no one with recorded authority
to sign it.

## Gate sign-off log

| Gate | What the client approves | Client approver | Date | Approved (Y/N) · Notes |
|------|--------------------------|-----------------|------|------------------------|
| 1 — Discovery | Context, vision, stakeholders, approver | | | **Not signed.** Blocked on Q12 (approver not named) |
| 2 — Problem & Goals | The problem and the success metrics | | | **Not signed.** Blocked on Q1, Q2 — G1's target has no measured baseline |
| 3 — Scope & Requirements | In/out-of-scope, features, acceptance criteria | | | **Not signed.** Blocked on Q5, Q7, Q10, Q11, Q13, Q14 |
| 4 — Feasibility & Risk | Risks, assumptions, high-level plan | | | **Not signed.** Blocked on Q3, Q4 |
| 5 — Final PRD approval | The complete PRD as baseline v1.0 | | | **Not signed.** Blocked on **Q6 (legal opinion)** above all else |

## Change-control log (after baseline v1.0)

Every change to a baselined requirement is logged, impact-assessed, and re-approved.
No entries yet — the PRD is not baselined.

| # | Requested change | Impact (scope / cost / time / risk) | Approver & date | Status |
|---|------------------|-------------------------------------|-----------------|--------|
| 1 | | | | |

## Decisions already recorded

These four were confirmed by the client on 2026-09-04 and are reflected throughout the
PRD. They are recorded here so that changing any of them is treated as a change request,
not a clarification.

| # | Decision | Consequence in the PRD |
|---|----------|------------------------|
| D1 | Business model is **both** principal buyer and marketplace | §6 MVP runs the principal model end to end; RISK-6 (working capital) and RISK-11 (cold start) both follow |
| D2 | "Future betting" means **forward contracts** — commercial supply agreements, not tradable instruments | FR-10 to FR-12; §6 out-of-scope items 1 and 2; RISK-7 |
| D3 | Vault holds a **Stellar stablecoin, platform-custodied** | FR-24 to FR-30; RISK-1, RISK-3, RISK-4; Q6 and Q8 |
| D4 | **Philippines first**, architected for later expansion | §8 localization and privacy NFRs; GDPR-equivalent rights from day 1 |
| D5 | A marketplace order transacts at **the farmer's asking price**, not the platform's published price | FR-5 amended to carry a price; FR-8 and FR-9 scope-noted. Recorded 2026-09-04 |
| D6 | MVP covers **both** Cordillera and Central Luzon | Answer to Q10. Widens §6, which scopes the MVP to one region and five commodities — implies two pilot sites at M7 |
