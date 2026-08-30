# Proof-first GitHub Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current catalog-style GitHub profile with a focused proof hub and a read-only, supply-chain-hardened validation workflow.

**Architecture:** `README.md` remains the only rendered product surface. A dependency-free Bash checker owns structural and external-link validation, while a read-only GitHub Actions workflow runs that checker and a checksum-verified actionlint binary. Obsolete generated vanity assets and their write-capable workflow are removed rather than redesigned.

**Tech Stack:** GitHub Flavored Markdown, Bash 3.2+, curl, GitHub Actions, actionlint 1.7.12

**Spec:** `docs/superpowers/specs/2026-08-30-proof-first-profile-design.md`

## Global Constraints

- Keep all public profile copy in English.
- Make `https://codevena.dev` the only primary call to action.
- Feature exactly Flashbuddy, Capypad, and ReviewGate as selected work.
- Use only claims already verified in the repository, public project metadata, or the canonical Brain notes.
- Do not add pricing, a paid service, Sponsors, seniority claims, private metrics, testimonials, or adoption claims.
- Do not add a package manifest, project-data generator, runtime dependency, or metrics service.
- Preserve the public email, X account, Düsseldorf location, and DE/EN languages.
- Remove the banner, view counter, snake, stats cards, and top-language card.
- Give the replacement workflow `contents: read` only and expose no secrets.
- Pin every `uses:` action to a full commit SHA.
- Do not mutate or delete the remote `output` branch.
- Do not push, open a pull request, merge, or deploy.
- Preserve unrelated user changes and stage exact paths only.

---

### Task 1: Proof-first README and repository-native checker

**Files:**
- Create: `scripts/check-profile.sh`
- Modify: `README.md`
- Delete: `assets/banner.jpg`

**Interfaces:**
- Consumes: an optional README path as `$1`; `CHECK_PROFILE_SKIP_NETWORK=1` for deterministic structure-only execution.
- Produces: exit code `0` for a conforming profile; non-zero with `profile-check: <reason>` for the first failed invariant.

- [ ] **Step 1: Create the profile checker before changing the README**

Create `scripts/check-profile.sh` with this exact implementation and mark it executable:

```bash
#!/usr/bin/env bash

set -euo pipefail

readme_path="${1:-README.md}"
skip_network="${CHECK_PROFILE_SKIP_NETWORK:-0}"

fail() {
  printf 'profile-check: %s\n' "$*" >&2
  exit 1
}

[[ -f "$readme_path" ]] || fail "README not found: $readme_path"

required_headings=(
  "Selected work"
  "More shipped"
  "Open source you can inspect"
  "Core stack"
  "Contact"
)

for heading in "${required_headings[@]}"; do
  grep -Fqx "### $heading" "$readme_path" \
    || fail "missing heading: $heading"
done

required_terms=(
  "https://codevena.dev"
  "Flashbuddy"
  "Capypad"
  "ReviewGate"
)

for term in "${required_terms[@]}"; do
  grep -Fq -- "$term" "$readme_path" \
    || fail "missing required proof: $term"
done

banned_terms=(
  "komarev.com"
  "github-snake"
  "stats.svg"
  "top-langs.svg"
  "assets/banner.jpg"
)

for term in "${banned_terms[@]}"; do
  if grep -Fq -- "$term" "$readme_path"; then
    fail "banned vanity asset reference: $term"
  fi
done

case "$skip_network" in
  0) ;;
  1)
    printf 'profile-check: ok (structure only)\n'
    exit 0
    ;;
  *) fail "CHECK_PROFILE_SKIP_NETWORK must be 0 or 1" ;;
esac

url_file="$(mktemp)"
trap 'rm -f "$url_file"' EXIT

if ! grep -Eo 'https://[^)>[:space:]"]+' "$readme_path" \
  | LC_ALL=C sort -u > "$url_file"; then
  fail "no HTTPS URLs found"
fi

url_count=0
while IFS= read -r url; do
  [[ -n "$url" ]] || continue
  http_code="$(curl \
    --location \
    --silent \
    --show-error \
    --retry 2 \
    --retry-delay 1 \
    --retry-all-errors \
    --connect-timeout 10 \
    --max-time 30 \
    --output /dev/null \
    --write-out '%{http_code}' \
    "$url")" || fail "URL request failed: $url"

  case "$http_code" in
    2??|3??) ;;
    *) fail "URL returned HTTP $http_code: $url" ;;
  esac

  url_count=$((url_count + 1))
done < "$url_file"

[[ "$url_count" -gt 0 ]] || fail "no HTTPS URLs found"
printf 'profile-check: ok (%d URLs)\n' "$url_count"
```

Run:

```bash
chmod +x scripts/check-profile.sh
bash -n scripts/check-profile.sh
```

Expected: both commands exit `0`.

- [ ] **Step 2: Run the causal RED against the current README**

Run:

```bash
CHECK_PROFILE_SKIP_NETWORK=1 bash scripts/check-profile.sh
```

Expected: non-zero with `profile-check: missing heading: Selected work`. This
proves the checker rejects the catalog-style profile before the product fix.

- [ ] **Step 3: Rewrite the README with the approved proof-first copy**

Replace `README.md` with:

```markdown
# Markus · Codevena

**I build and run web products end to end.**

From product decisions and AI-assisted implementation to payments, deployment,
and operations — carried through to something live.

**[See the production case studies →](https://codevena.dev)**

`Product to production. Edge to metal.`

---

### Selected work

| Work | What shipped | Proof |
|---|---|---|
| [**Flashbuddy**](https://flashbuddy.app) | Learning SaaS from study loop to billing. | FSRS scheduling · AI-generated flashcards · quests and streaks · four Stripe tiers |
| [**Capypad**](https://capypad.com) | SSR coding quiz with a DE/EN interface and exercises across 10 programming languages. | pgvector HNSW dedup on insert · per-request CSP nonce · private database network |
| [**ReviewGate**](https://github.com/Codevena/reviewgate) | Fail-closed review gate for AI coding agents. | six reviewer paths · local audit trail · dogfooded in daily development |

---

### More shipped

<details>
<summary>Eight more live products and completed builds</summary>

- [**AzadiFeed**](https://azadifeed.com) — multilingual crisis communication for the Iranian community, with an AI-translated RSS pipeline and Telegram breaking-news push.
- [**AI Builds**](https://aibuilds.dev) — a site where AI agents collectively build and evolve pages through an MCP backbone.
- [**Shattergrid**](https://shattergrid.com) — browser Geometry-Wars clone with a fixed-timestep Three.js simulation and a 20K particle pool.
- [**Stack Surge**](https://stacksurge.app) — Canvas arcade stacker with cross-device progress, streaks, and fever mode.
- [**DefOrbit**](https://deforbit.com) — real-time two-player browser shooter using Cloudflare Durable Objects and D1.
- [**ToolPrime**](https://toolprime.dev) — free browser utilities with no signup and no ads.
- [**Ludotek**](https://github.com/Codevena/ludotek) — self-hosted retro library with device scanning and IGDB enrichment.
- [**CVMake**](https://cvmake.codevena.dev) — YAML-to-PDF CV builder with 12 templates, an npm CLI, and visual-regression tests.

</details>

---

### Open source you can inspect

- [**ReviewGate**](https://github.com/Codevena/reviewgate) — independent review gates for Claude Code, Codex, Gemini, OpenCode, OpenRouter, and Ollama.
- [**Cleanbuddy**](https://github.com/Codevena/cleanbuddy) — allowlist-guarded macOS cleanup with 130 tests.
- [**CVMake**](https://github.com/Codevena/cvmake) — MIT-licensed CV builder, live editor, and npm CLI.
- [**FixBuddy**](https://github.com/Codevena/fixbuddy) — GitHub issue-to-patch orchestration with a two-agent review loop.

---

### Core stack

**Product** · TypeScript · Next.js · React · Node.js · PostgreSQL<br>
**Edge & infrastructure** · Cloudflare · Docker · Hetzner · Coolify<br>
**AI-assisted delivery** · OpenAI · Anthropic · MCP · ReviewGate<br>
**Verification** · Vitest · Playwright · Jest · axe-core

---

### Contact

The best way to reach me is **[hello@codevena.dev](mailto:hello@codevena.dev)**.
I work asynchronously and reply in writing.

[codevena.dev](https://codevena.dev) · [@codevena on X](https://x.com/codevena)

Düsseldorf, Germany · DE / EN
```

- [ ] **Step 4: Remove the approved unused binary asset**

Run the exact, recoverable Git operation:

```bash
git rm -- assets/banner.jpg
```

Expected: only `assets/banner.jpg` is staged for deletion. It remains recoverable
from Git history.

- [ ] **Step 5: Run GREEN structure and full-link checks**

Run:

```bash
CHECK_PROFILE_SKIP_NETWORK=1 bash scripts/check-profile.sh
bash scripts/check-profile.sh
```

Expected: structure-only prints `profile-check: ok (structure only)` and the
full run prints `profile-check: ok (<positive count> URLs)` with exit `0`.

- [ ] **Step 6: Commit the proof-first surface and checker**

Run:

```bash
git add README.md scripts/check-profile.sh assets/banner.jpg
git diff --cached --name-only
git diff --cached --check
git commit -m "feat(profile): focus public proof and validation"
```

Expected staged paths: `README.md`, `assets/banner.jpg`, and
`scripts/check-profile.sh`; repository hooks pass.

---

### Task 2: Replace the vulnerable generator with read-only validation

**Files:**
- Delete: `.github/workflows/snake.yml`
- Create: `.github/workflows/profile-check.yml`
- Create: `.github/SECURITY.md`
- Create: `NOTICE.md`

**Interfaces:**
- Consumes: `scripts/check-profile.sh`; actionlint release
  `v1.7.12`; `actions/checkout` release `v7.0.1`.
- Produces: a read-only workflow running on changes, Monday schedule, and manual dispatch; a private security-reporting route; an explicit copyright boundary.

- [ ] **Step 1: Independently trace the security boundary before editing**

Dispatch one read-only security investigator with this assignment:

```text
Repository: /Users/markus/Developer/codevena-github-profile
Finding: .github/workflows/snake.yml runs mutable third-party action tags with contents: write on push, schedule, and manual dispatch.
Trace the current source-to-sink path, confirm what legitimate behavior must remain after the proof-first README removes generated assets, and identify any alternate write-capable workflow path. Do not edit, stage, commit, or delegate. Separate facts, inferences, and unresolved questions and cite repository-relative lines.
```

Reconcile the report against `.github/workflows/snake.yml` and `README.md`. The
selected boundary remains deletion only if no rendered profile feature still
depends on the generated output.

- [ ] **Step 2: Record the vulnerable pre-patch evidence**

Run:

```bash
rg -n 'contents: write|uses:.*@(v[0-9]+|main|master)' .github/workflows/snake.yml
```

Expected: `contents: write`, `Platane/snk/svg-only@v3`, and
`crazy-max/ghaction-github-pages@v4` are reported.

- [ ] **Step 3: Delete the obsolete workflow and create the read-only replacement**

Delete `.github/workflows/snake.yml` and create
`.github/workflows/profile-check.yml` with:

```yaml
name: Validate GitHub profile

on:
  push:
    branches:
      - main
  pull_request:
  schedule:
    - cron: "17 6 * * 1"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: profile-check-${{ github.ref }}
  cancel-in-progress: true

jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Validate profile structure and links
        run: bash scripts/check-profile.sh

      - name: Install actionlint
        env:
          ACTIONLINT_VERSION: "1.7.12"
          ACTIONLINT_SHA256: "8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"
        run: |
          archive="actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"
          url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${archive}"
          curl --fail --silent --show-error --location \
            --retry 3 --retry-delay 2 --retry-all-errors \
            --output "/tmp/${archive}" "$url"
          printf '%s  %s\n' "$ACTIONLINT_SHA256" "/tmp/${archive}" \
            | sha256sum --check --strict
          tar -xzf "/tmp/${archive}" -C /tmp actionlint
          /tmp/actionlint -version

      - name: Lint workflows
        run: /tmp/actionlint
```

The checkout SHA is the commit referenced by the official `v7.0.1` tag on
2026-08-30. The actionlint checksum is the official
`actionlint_1.7.12_linux_amd64.tar.gz` release checksum on the same date.

- [ ] **Step 4: Add the security-reporting policy**

Create `.github/SECURITY.md` with:

```markdown
# Security policy

## Supported version

Only the current `main` branch is maintained.

## Reporting a vulnerability

Please report profile-automation vulnerabilities privately to
[hello@codevena.dev](mailto:hello@codevena.dev) with `[Security]` in the
subject. Include the affected file, reproduction steps, expected impact, and a
suggested mitigation when available.

Please do not open a public issue before the report has been acknowledged. This
repository contains no application runtime or customer data; the relevant
security boundary is its GitHub Actions automation and repository permissions.
```

- [ ] **Step 5: Add the copyright and reuse boundary**

Create `NOTICE.md` with:

```markdown
# Copyright and reuse

Copyright © 2026 Markus Wiesecke / Codevena. All rights reserved.

This repository is public because GitHub requires a public, account-named
repository to render a profile README. Public visibility does not grant a
license to reuse the profile copy, the Codevena name or identity, or included
brand assets.

Unless a file explicitly states otherwise, no license is granted for copying,
modifying, distributing, or sublicensing this repository's contents. Projects
linked from the profile keep their own, separately stated licenses.
```

- [ ] **Step 6: Verify the narrow security fix and legitimate replacement**

Run:

```bash
actionlint
bash scripts/check-profile.sh
if rg -n 'contents: write|uses:.*@(v[0-9]+|main|master)' .github; then
  exit 1
fi
if rg --no-filename '^[[:space:]]*uses:' .github/workflows \
  | rg -v '@[0-9a-f]{40}([[:space:]]+#.*)?$'; then
  exit 1
fi
test ! -e .github/workflows/snake.yml
test ! -e assets/banner.jpg
```

Expected: actionlint and the full profile check pass; the negative search emits
nothing; both removed paths are absent.

- [ ] **Step 7: Commit the read-only automation and policies**

Run:

```bash
git add .github/workflows/snake.yml .github/workflows/profile-check.yml .github/SECURITY.md NOTICE.md
git diff --cached --name-only
git diff --cached --check
git commit -m "ci(profile): replace generated vanity assets with read-only checks"
```

Expected staged paths: the deleted snake workflow and the three created files;
repository hooks pass.

---

### Task 3: Independent review, final verification, and durable context

**Files:**
- Modify if a confirmed review finding requires it: only files changed in Tasks 1–2
- Modify: `/Users/markus/Documents/Brain/02 Projekte/Archiv/codevena-github-profile.md`
- Modify: `/Users/markus/Documents/Brain/05 Daily Notes/2026-08-30.md`

**Interfaces:**
- Consumes: the complete diff from the pre-implementation commit and all verification commands.
- Produces: one security bypass/regression review, one public-interface/copy review, current Brain state, and a clean verified repository tree.

- [ ] **Step 1: Run the required security patch-candidate review**

Dispatch one fresh read-only reviewer with only this assignment and the current
diff, without the implementation rationale or prior investigator report:

```text
Repository: /Users/markus/Developer/codevena-github-profile
Finding: the old profile asset workflow ran mutable third-party tags with contents: write. Review the candidate diff for a surviving write-capable route, mutable executable dependency, checksum or download bypass, trigger regression, or loss of legitimate profile validation. Do not edit, stage, commit, or delegate. Report only concrete, source-backed bypasses or regressions and how to verify each.
```

Reproduce every reported issue before changing code. Apply only confirmed fixes
within the approved scope, then rerun Task 2 Step 6.

- [ ] **Step 2: Run an independent public-interface and claim review**

Dispatch a separate read-only reviewer:

```text
Repository: /Users/markus/Developer/codevena-github-profile
Review the current candidate diff against docs/superpowers/specs/2026-08-30-proof-first-profile-design.md. Check conversion hierarchy, English clarity, supported factual claims, link destinations, accessibility of the Markdown structure, removal of vanity elements, rights language, and scope. Do not edit, stage, commit, or delegate. Report CRITICAL/WARN findings only, each with a one-sentence minimal fix.
```

Confirm findings against source or live endpoints and fix only confirmed
CRITICAL/WARN items. If fixes are needed, stage their exact paths and commit with
`fix(profile): address final review findings` after focused checks pass.

- [ ] **Step 3: Run the full unchanged-tree verification gate**

Run sequentially, not concurrently:

```bash
bash -n scripts/check-profile.sh
CHECK_PROFILE_SKIP_NETWORK=1 bash scripts/check-profile.sh
bash scripts/check-profile.sh
actionlint
git diff --check
test -z "$(git status --short)"
```

Then run the full-history secret scan without printing secret values:

```bash
scan_report="$(mktemp)"
gitleaks git . --redact=100 --no-banner \
  --report-format json --report-path "$scan_report" >/dev/null 2>&1
rm -f "$scan_report"
```

Expected: every command exits `0`, the link count is positive, actionlint emits
no findings, the worktree is clean, and Gitleaks reports no finding.

- [ ] **Step 4: Update the canonical archived Brain note without adding open work**

Append this completed milestone to
`/Users/markus/Documents/Brain/02 Projekte/Archiv/codevena-github-profile.md`:

```markdown
### 30.08.2026 — Proof-first-Profilumbau

- Profil von einem gleichgewichteten Produktkatalog auf drei Beweise fokussiert:
  Flashbuddy, Capypad und ReviewGate. Primäre Aktion ist jetzt der Weg zu den
  Produktions-Case-Studies auf `codevena.dev`; Kontakt bleibt schriftlich und
  asynchron.
- View-Counter, Snake, Stats-/Sprachkarten und der ungenutzte generische Banner
  entfernt. Der schreibende Asset-Workflow ist vollständig entfallen.
- Ersatz ist eine read-only CI mit SHA-gepinntem Checkout,
  checksum-verifiziertem actionlint sowie Struktur- und Linkprüfung.
- Repository bleibt als kommerzielles Marken-Asset öffentlich, aber ohne
  Open-Source-Lizenz; `NOTICE.md` und privater Security-Meldeweg ergänzen die
  Grenze.
- Abschluss: vollständiger Linkcheck, actionlint, Gitleaks-History-Scan und
  unabhängige Reviews bestanden. Repo bleibt anschließend Maintenance-only.
```

Keep the YAML `status: archiviert` and the existing status paragraph intact.

- [ ] **Step 5: Record the material milestone in the current Daily Note**

Append this concise entry to
`/Users/markus/Documents/Brain/05 Daily Notes/2026-08-30.md`:

```markdown
## Codevena GitHub-Profil — Proof-first-Umbau abgeschlossen

Das öffentliche Profil zeigt jetzt drei belegte Arbeiten statt eines
gleichgewichteten Produktkatalogs und führt primär zu den Case Studies auf
codevena.dev. Vanity-Assets samt schreibendem Workflow sind entfernt; read-only
CI, Link-/Strukturprüfung, actionlint, Security-Meldeweg und Copyright-Grenze
sind ergänzt. Verifikation und Review-Evidenz stehen in
[[codevena-github-profile]].
```

- [ ] **Step 6: Inspect final state and hand off GitHub account-only actions**

Run:

```bash
git log --oneline --decorate -5
git status --short --branch
git ls-files
```

Expected: the project repository is clean and ahead of `origin/main` only by the
approved local commits. Report that no push, deployment, output-branch deletion,
or GitHub account mutation occurred.

Recommend these account-level pins without changing them:

1. `reviewgate`
2. `cvmake`
3. `cleanbuddy`
4. `fixbuddy`
5. `ludotek` only if a fifth pin adds useful breadth
