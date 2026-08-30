# Proof-first GitHub Profile Design

**Date:** 2026-08-30
**Status:** Approved direction; implementation pending written-spec review

## Purpose

Turn the `Codevena/Codevena` profile README into a focused proof hub. A visitor
should understand within one screen that Markus ships and operates complete web
products, see three inspectable examples, and have one primary next step: open
the production case studies on `codevena.dev`.

The profile is a public commercial brand asset, not a standalone product and not
an open-source community project.

## Audience and action hierarchy

The primary audience is technical decision-makers and developer peers arriving
from GitHub repositories, search, social posts, or a shared profile link.

Actions are ordered deliberately:

1. **Primary:** open the production case studies on `codevena.dev`.
2. **Secondary:** inspect public source repositories.
3. **Tertiary:** contact Markus by email or follow Codevena on X.

The profile does not sell an architecture audit, claim seniority, solicit calls,
or promote GitHub Sponsors. Those paths would be premature relative to the
current proof and personal-brand strategy.

## Content design

### Hero

The README stays in English and opens with direct, evidence-compatible copy:

- Identity: `Markus · Codevena`
- Headline: `I build and run web products end to end.`
- Supporting line: product decisions, AI-assisted implementation, payments,
  deployment, and operations are carried through to a live result.
- Primary CTA: `See the production case studies →` linking to
  `https://codevena.dev`.

`Edge to metal` may remain as a secondary brand phrase, but the current
`One developer`, `No team`, and `no managed-everything philosophy` wording is
removed. The hero contains no profile-view counter or decorative social-badge
row competing with the primary CTA.

### Selected work

Exactly three projects receive prominent treatment:

| Project | Role in the proof set | Claims allowed in the README |
|---|---|---|
| Flashbuddy | Complete commercial SaaS | Live learning SaaS; FSRS scheduling; AI-assisted card generation; Stripe subscriptions with monthly and yearly billing |
| Capypad | Application and security engineering | DE/EN interface; quizzes across ten programming languages; pgvector semantic deduplication on insert; per-request CSP nonce; no public database port |
| ReviewGate | Public, inspectable engineering process | Fail-closed agent review gate; six reviewer paths; local audit trail; dogfooded in daily development |

Each entry links directly to the live product or public repository and states
what shipped plus a concrete proof. The profile must not invent user counts,
revenue, uptime, performance numbers, testimonials, or adoption metrics.

### Remaining work

The remaining shipped products appear in one compact `More shipped` disclosure,
not as equal-weight case studies. The list covers AzadiFeed, AI Builds,
Shattergrid, Stack Surge, DefOrbit, ToolPrime, Ludotek, and CVMake.

Public source remains visible in a concise `Open source you can inspect` section
covering ReviewGate, Cleanbuddy, CVMake, and FixBuddy. Duplication of ReviewGate
is acceptable because the two sections answer different questions: strongest
proof versus available source.

### Stack and contact

The current inventory of technologies is replaced by a short core-stack block:

- Product: TypeScript, Next.js, React, Node.js, PostgreSQL
- Edge and infrastructure: Cloudflare, Docker, Hetzner, Coolify
- AI-assisted delivery: OpenAI, Anthropic, MCP, ReviewGate
- Verification: Vitest, Playwright, Jest, axe-core

Contact copy stays positive and asynchronous: email is the best contact method,
and Markus replies in writing. The existing public email address, X account,
general Düsseldorf location, and DE/EN language information remain visible.

## Removed presentation and automation

The following are removed from the profile because they add vanity or visual
noise without strengthening the proof:

- Komarev profile-view badge
- contribution snake
- generated stats and top-language cards
- unused `assets/banner.jpg`
- `.github/workflows/snake.yml`

Deleting the generation workflow is also the narrowest complete fix for the
validated security finding: mutable third-party action tags currently execute
on a schedule with `contents: write`. Once the generated assets are no longer
part of the profile, no legitimate write-capable workflow behavior remains to
preserve.

The existing remote `output` branch is outside this repository patch. It becomes
unreferenced but is not deleted, force-pushed, or otherwise mutated.

## Repository checks

Create `scripts/check-profile.sh` as the repository-native validation boundary.
It accepts an optional README path and supports a structure-only mode for local
tests. It must:

1. require the headings `Selected work`, `More shipped`,
   `Open source you can inspect`, `Core stack`, and `Contact`;
2. require the primary `https://codevena.dev` link and the three selected works;
3. reject references to `komarev.com`, `github-snake`, `stats.svg`,
   `top-langs.svg`, and `assets/banner.jpg`;
4. extract unique HTTPS URLs from the README;
5. verify every extracted URL with bounded `curl` retries and timeouts unless
   structure-only mode is active;
6. return non-zero on any structural or network failure and identify only the
   failing URL or rule, never response bodies.

The behavioral RED is the existing README: it lacks the required proof-first
headings and contains banned vanity assets. After the README rewrite, the same
checker must pass.

Add `.github/workflows/profile-check.yml` with:

- `contents: read` permissions only;
- push, pull-request, weekly schedule, and manual triggers;
- `actions/checkout` pinned to a verified full commit SHA;
- the repository profile checker;
- actionlint installed from a versioned release whose archive checksum is
  verified before execution.

No new package manifest, runtime dependency, generated project registry, or
metric collection service is introduced.

## Security and rights

Add `.github/SECURITY.md` with `hello@codevena.dev` as the private reporting
route for profile automation problems. Reports should include affected file,
reproduction, impact, and suggested mitigation; public disclosure should wait
for acknowledgement.

Add `NOTICE.md` stating that the profile copy, Codevena identity, and brand
assets are copyrighted and not offered under an open-source license. The
repository remains public only because GitHub requires that visibility for a
profile README.

The replacement CI workflow receives no write permission and no project
secrets. Downloaded executable tooling must be versioned and checksum-verified.

## Files

| Path | Change | Responsibility |
|---|---|---|
| `README.md` | Rewrite | Proof-first public profile |
| `.github/workflows/snake.yml` | Delete | Remove obsolete vanity generation and write-capable boundary |
| `assets/banner.jpg` | Delete | Remove unused generic brand visual |
| `scripts/check-profile.sh` | Create | Deterministic structure and link validation |
| `.github/workflows/profile-check.yml` | Create | Read-only scheduled and change-triggered CI |
| `.github/SECURITY.md` | Create | Private vulnerability-reporting route |
| `NOTICE.md` | Create | Copyright and reuse boundary |
| `docs/superpowers/plans/2026-08-30-proof-first-profile.md` | Create after spec approval | Executable implementation plan |

The final implementation also updates the canonical archived Brain project note
with the completed one-off rebuild and records the milestone in the current
Daily Note. It leaves the Brain note archived and introduces no open task there.

## Verification and acceptance

The implementation is accepted only when all of the following hold on the
unchanged final tree:

- the profile checker demonstrably fails against the pre-rewrite README for the
  intended structural and banned-asset reasons;
- `bash scripts/check-profile.sh` passes against the final README, including all
  external links;
- `actionlint` passes all workflow files;
- the replacement workflow contains no `contents: write` permission and every
  `uses:` reference is a full commit SHA;
- no removed asset is referenced or tracked;
- `gitleaks git .` passes over the complete repository history;
- `git diff --check` passes;
- an independent reviewer finds no concrete security bypass, broken legitimate
  profile behavior, unsupported claim, or conversion regression;
- the worktree contains only the approved repository and Brain-note changes.

## Explicit non-goals

- no paid service, pricing, sponsor button, or revenue promise;
- no GitHub profile generator or structured project-data subsystem;
- no fabricated or private business metrics;
- no modification of GitHub pinned repositories or account settings;
- no deletion of the remote `output` branch;
- no deployment, push, pull request, or merge.
