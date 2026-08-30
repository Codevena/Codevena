# Visual Proof Profile and Contribution Snake Design

**Date:** 2026-08-30
**Status:** Approved direction; implementation pending written-spec review

## Purpose

Restore the visual identity that made the Codevena GitHub profile feel alive
without undoing the proof-first content hierarchy or recreating the previous
supply-chain exposure.

The profile remains a focused commercial proof hub. Its primary action is still
the production case-study link on `codevena.dev`; badges and animation add
personality and recognizable GitHub-native motion around that hierarchy.

## Visual hierarchy

The README keeps the current English hero, factual proof claims, selected-work
table, collapsed secondary work, open-source links, concise stack, and contact
copy.

The presentation order becomes:

1. identity, proof-first headline, supporting sentence, and primary case-study
   CTA;
2. one compact badge row;
3. exactly three selected projects;
4. one animated contribution-snake section;
5. collapsed remaining work, inspectable open source, core stack, and contact.

The motion must not precede or visually replace the primary CTA or the selected
proof set.

## Badge row

Restore the four compact `flat-square` badges from the previous profile:

- Portfolio badge linking to `https://codevena.dev`;
- live profile-view badge from `komarev.com`;
- X badge linking to `https://x.com/codevena`;
- email badge linking to `mailto:hello@codevena.dev`.

Every image has useful alt text. The Portfolio badge reinforces the same
primary destination rather than introducing a competing offer. No GitHub
trophy grid, sponsor badge, decorative technology wall, or additional vanity
counter is added.

## Contribution trail

Add an H2 section named `Contribution trail` immediately after `Selected work`.
It contains a centered responsive `<picture>` with separate light- and
dark-mode sources:

- `https://raw.githubusercontent.com/Codevena/Codevena/output/github-snake.svg`
- `https://raw.githubusercontent.com/Codevena/Codevena/output/github-snake-dark.svg`

The fallback image uses the light asset and the alt text
`Animated contribution snake for Codevena's GitHub activity`.

The previous `stats.svg` and `top-langs.svg` cards stay out of the README. Their
existing files on the remote `output` branch are not deleted or modified by
this change.

## Automation architecture

Create a dedicated contribution-snake workflow. It runs daily, on manual
dispatch, and on pushes to `main`. Concurrency prevents overlapping publishers.

The workflow has two trust zones:

### Generate job

- grants no more than `contents: read`;
- runs the Platane snake generator from a verified full commit SHA;
- produces only `github-snake.svg` and `github-snake-dark.svg` in a temporary
  artifact directory;
- verifies both files are non-empty, bounded-size SVG documents;
- rejects script elements, `foreignObject`, JavaScript URLs, inline event
  handlers, and other active-content patterns;
- transfers the validated files with SHA-pinned official GitHub artifact
  actions.

The third-party generator never runs in a job holding repository write
permission or persisted repository credentials.

### Publish job

- starts only after a successful Generate job;
- grants `contents: write` only at job scope;
- runs only SHA-pinned official GitHub actions plus repository-owned shell;
- checks out the existing `output` branch;
- downloads and revalidates the generated artifact;
- stages exactly `github-snake.svg` and `github-snake-dark.svg`;
- verifies the staged path set before committing;
- pushes only `HEAD:output` and exits cleanly when the SVGs are unchanged.

No third-party publisher action, general build directory, stats-card download,
branch deletion, force-push, or `main` mutation is permitted.

## Profile validation

Extend `scripts/check-profile.sh` so the repository contract requires:

- the existing exact hero CTA before `Selected work`;
- exactly the four approved badges and their destinations;
- exactly three selected-work rows and the existing name-to-target link pairs;
- one `Contribution trail` H2 after `Selected work` and before `More shipped`;
- both exact light/dark snake URLs and the approved fallback alt text.

The retired-asset ban continues to reject `stats.svg`, `top-langs.svg`, and
`assets/banner.jpg`. It no longer rejects the approved `github-snake` and
`komarev.com` references.

Extend `scripts/test-check-profile.sh` with causal negative fixtures for a
missing badge row, a missing snake source, wrong section placement, and any
reintroduced stats card. Existing CTA and selected-work fixtures remain.

## Verification and review

Before completion:

- demonstrate the new regression fixtures fail against the pre-change checker;
- pass Bash syntax and ShellCheck for repository scripts;
- pass structure-only and live-link profile checks;
- pass actionlint for every workflow;
- prove every `uses:` reference is a full 40-character SHA;
- prove only the dedicated publisher job has `contents: write`;
- validate the generated SVGs against the active-content rejection rules;
- scan full Git history with Gitleaks;
- obtain an independent security-boundary review and an independent visual/
  public-interface review;
- after authorized integration, confirm the workflow succeeds, the two output
  SVGs update, and the live GitHub profile renders badges and the animated
  light/dark snake without restoring the stats cards.

## Scope boundaries

- The repository remains public without an open-source license.
- `NOTICE.md`, `.github/SECURITY.md`, the proof-first claims, and the primary
  case-study CTA remain intact.
- No GitHub pinned-repository settings, profile metadata, deployments, or
  unrelated product sites are changed.
- Existing `stats.svg` and `top-langs.svg` files on `output` are left untouched
  because deleting remote artifacts is not required to restore the requested
  presentation.
