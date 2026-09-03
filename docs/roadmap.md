# Roadmap

This document records what Farmalengke intends to build and in what order. It is a
starting point for discussion, not a commitment — the scope should be settled by
people who actually farm, and it will change.

## The problem

Decisions that determine a season's yield — when to plant, how much water to apply,
whether a discoloured leaf is a deficiency or a disease, what a crop is worth this
week — are often made without the information that would make them better. That
information frequently exists, but is scattered, region-locked, behind a paywall,
in the wrong language, or in the wrong units.

Farmalengke's premise is that closing the gap between existing knowledge and the
person making the decision is more tractable, and more useful, than generating new
agronomic science.

## Principles

- **Usable offline.** Assume intermittent connectivity and a low-end phone. A tool
  that needs a stable connection is not available at the moment it is needed.
- **Cite the source.** Any figure a user might act on links back to where it came
  from.
- **No false precision.** Say "we don't know" rather than produce a confident
  number from thin data.
- **Region-aware by default.** Crop varieties, units, seasons, and regulations are
  inputs, not constants.
- **Farmers own their data.** Anything collected is theirs, and is not a condition
  of using the tool.

## Phase 0 — Foundation (current)

- [x] Initialize the repository, license, and contribution process
- [ ] Agree the initial problem to solve, with input from working farmers
- [ ] Choose a technology stack that fits offline-first, low-end-device constraints
- [ ] Set up continuous integration and a test harness
- [ ] Define the data model for crops, regions, units, and measurements

## Phase 1 — A single useful thing

Rather than build a platform, build one tool that solves one problem well, and
learn from it. Candidates to choose between:

- **Crop calendar** — planting, input, and harvest timing for a given crop and
  region, from published extension-service guidance.
- **Irrigation guidance** — water recommendations from local weather data, crop
  stage, and soil type.
- **Input calculator** — fertilizer, seed, and spacing quantities for a given plot
  size and crop.
- **Record keeping** — a simple log of what was planted, applied, and harvested,
  which is the precondition for any later analysis.

Selection criteria: it must be useful without a network, verifiable against a
published source, and testable with real users within one season.

## Phase 2 — Data and reach

- Open, versioned datasets for crops and regions, with provenance for every record
- Localization and translation infrastructure
- An import and export path so farmers can take their records elsewhere
- Optional integration with public weather and market-price sources

## Phase 3 — Sharing what works

- Aggregate anonymized outcomes to surface which practices work where — strictly
  opt-in
- Publish methodology alongside every result

## Explicitly out of scope for now

- Machine learning models trained on data we do not yet have
- Marketplace, payments, or logistics features
- Hardware and IoT sensor integration
- Anything requiring a permanent network connection

These may become relevant later. They are excluded now because they would consume
the effort needed to make one thing genuinely useful.

## Open questions

- Which region and crop should Phase 1 target first, and who will test it?
- What is the minimum viable device and connectivity assumption?
- Which existing open agricultural datasets can be built on rather than duplicated?
- Who reviews agronomic content for correctness before it reaches users?

Have an answer, or a better question? Open an issue.
