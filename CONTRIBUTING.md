# Contributing to Farmalengke

Thanks for your interest. Farmalengke aims to improve farming efficiency, and that
goal needs more than code — field experience, agronomic review, translation, and
clear documentation all move the project forward.

Everyone participating is expected to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Describe a real problem.** Open an issue explaining a concrete inefficiency you
  have seen in the field: what happens today, why it costs time or yield, and who
  it affects. Context beats abstraction.
- **Review agronomy.** If a recommendation in this repository is wrong, unsafe, or
  regionally inappropriate, say so and point to a source.
- **Improve documentation.** Corrections and clarifications are always welcome.
- **Translate.** The project should not be English-only.
- **Write code.** See the workflow below.

## Before you start work

The project is early, and the scope is still being settled in
[`docs/roadmap.md`](docs/roadmap.md). For anything beyond a small fix, please open
an issue first and agree on the approach. That avoids someone spending a weekend
on a change the project cannot merge.

## Workflow

1. Fork the repository and create a branch off `main`.
2. Make your change, keeping the commit history readable.
3. Open a pull request that explains **what** changed and **why**.
4. Respond to review comments; maintainers may ask for changes before merging.

### Commit messages

Write a short imperative subject line (roughly 72 characters or fewer), then a
blank line, then the reasoning if it is not obvious from the diff:

```
Add soil moisture units to the crop schema

Readings arrived in both percent and centibars, which made regional
datasets impossible to compare.
```

### Pull requests

- Keep each pull request to a single logical change; small ones get reviewed faster.
- Update the documentation in the same pull request as the behavior it describes.
- Say what you did to verify the change. If you could not test something, say that
  too — an honest gap is more useful than an untested claim.

## Data and sources

Agricultural advice affects livelihoods. Anything presented as fact — a yield
figure, a spacing recommendation, a pesticide interval — must cite a source, and
the source must be one a reader can check. Do not merge numbers of unknown origin.

Only contribute data you have the right to share, and note its license and
provenance.

## Regional assumptions

Crops, climates, units, calendars, and regulations differ everywhere. Avoid
hard-coding one region's assumptions as the default. Where a value is
region-specific, make that explicit rather than implicit.

## Licensing

By contributing, you agree that your contributions are licensed under the
[Apache License 2.0](LICENSE), the same license that covers the project.

## Questions

Open an issue. A question that seems obvious to you is often one the documentation
should have answered.
