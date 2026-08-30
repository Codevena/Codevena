# Visual Proof Profile and Contribution Snake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the approved badge row and an automatically refreshed light/dark contribution snake while preserving the proof-first profile and isolating repository write permission from the third-party generator.

**Architecture:** README presentation and repository-native validation stay in the existing profile boundary. A new asset validator accepts only two bounded passive SVG files. A dedicated two-job workflow generates those files with read permission, transfers them through pinned official artifact actions, then lets a separate publisher update only the two allowed paths on `output` with job-scoped write permission.

**Tech Stack:** GitHub-flavored Markdown and HTML, Bash 3.2+, GitHub Actions, Platane/snk v3.5.0, official GitHub checkout/upload/download actions, actionlint, ShellCheck, curl, Gitleaks

**Spec:** `docs/superpowers/specs/2026-08-30-visual-proof-snake-design.md`

## Global Constraints

- Keep the exact proof-first headline, primary case-study CTA, three selected projects, corrected product claims, collapsed secondary work, open-source list, core stack, and contact copy.
- Restore exactly the Portfolio, profile-view, X, and email badges; add no trophy grid, sponsor badge, technology wall, or second counter.
- Add exactly one `Contribution trail` H2 after `Selected work` and before `More shipped`.
- Embed only `github-snake.svg` and `github-snake-dark.svg`; never embed `stats.svg` or `top-langs.svg`.
- The third-party snake generator may run only with `contents: read`; it must never run in the publisher job or receive persisted checkout credentials.
- Only the `publish` job in `.github/workflows/contribution-snake.yml` may declare `contents: write`.
- Every `uses:` reference must be a verified full 40-character commit SHA.
- The publisher may update only `github-snake.svg` and `github-snake-dark.svg` on the existing `output` branch; no force-push, deletion, or `main` mutation.
- Existing `stats.svg` and `top-langs.svg` files on `output` remain untouched.
- No new package dependency, license, provider secret, deployment, GitHub pin change, or product-site mutation.
- Do not push, dispatch the workflow, or otherwise mutate GitHub until Markus separately authorizes integration.

## Verified immutable action inputs

The following official release tags and immutable commits were resolved from the upstream GitHub repositories on 2026-08-30:

| Action | Release | Commit SHA |
|---|---|---|
| `actions/checkout` | `v7.0.1` | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/upload-artifact` | `v7.0.1` | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| `actions/download-artifact` | `v8.0.1` | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` |
| `Platane/snk` | `v3.5.0` | `d8f6715049803e982ee5ff501b6b9b7d5deeb09b` |

The pinned Platane action itself selects the immutable container digest
`platane/snk@sha256:3a66a51ca8eaecc1e841bc8baae39bd88079e57419850d1ed005eee2bbfce940`.

---

### Task 1: Add a reusable passive-SVG security boundary

**Files:**
- Create: `scripts/check-snake-assets.sh`
- Create: `scripts/test-check-snake-assets.sh`

**Interfaces:**
- Consumes: an optional directory argument, defaulting to `dist`.
- Produces: exit `0` only for a directory containing exactly two regular, non-symlink, passive SVG files named `github-snake.svg` and `github-snake-dark.svg`; prints `snake-assets: ok (2 passive SVGs)` on success.

- [ ] **Step 1: Write the validator regression suite first**

Create executable `scripts/test-check-snake-assets.sh`. It must create a
task-scoped temporary root and these eight directories: `safe`, `missing`,
`extra`, `script`, `foreign-object`, `event-handler`, `external-reference`,
and `css-external-reference`.

Use this safe fixture body for both approved names:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 24">
  <style>.dot{fill:#40c463;animation:pulse 2s linear infinite}@keyframes pulse{50%{opacity:.5}}</style>
  <rect class="dot" x="2" y="2" width="20" height="20" rx="4" />
  <rect class="dot" x="28" y="2" width="20" height="20" rx="4" />
</svg>
```

The suite must first assert the safe pair passes, then assert the following
mutations fail with the named message fragment:

| Fixture | Mutation | Expected message fragment |
|---|---|---|
| `missing` | omit `github-snake-dark.svg` | `expected exactly 2 asset entries` |
| `extra` | add `unexpected.svg` | `expected exactly 2 asset entries` |
| `script` | add `<script>alert(1)</script>` | `active SVG content rejected` |
| `foreign-object` | add `<foreignObject>` | `active SVG content rejected` |
| `event-handler` | add `onload="alert(1)"` | `active SVG content rejected` |
| `external-reference` | add `<image href="https://evil.example/x" />` | `external SVG reference rejected` |
| `css-external-reference` | add `<style>@import url(https://evil.example/x.css);</style>` | `external SVG reference rejected` |

Cleanup may remove only the explicitly named files, captured outputs, fixture
directories, and temporary root created by the test. The success line is
`snake-assets-test: ok (1 safe + 7 rejected fixtures)`.

Use this complete test structure:

```bash
#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
checker="$script_dir/check-snake-assets.sh"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/snake-assets-test.XXXXXX")"
safe_dir="$tmp_root/safe"
missing_dir="$tmp_root/missing"
extra_dir="$tmp_root/extra"
script_dir_fixture="$tmp_root/script"
foreign_dir="$tmp_root/foreign-object"
event_dir="$tmp_root/event-handler"
external_dir="$tmp_root/external-reference"
css_external_dir="$tmp_root/css-external-reference"

fixture_dirs=(
  "$safe_dir" "$missing_dir" "$extra_dir" "$script_dir_fixture"
  "$foreign_dir" "$event_dir" "$external_dir" "$css_external_dir"
)

cleanup() {
  for fixture_dir in "${fixture_dirs[@]}"; do
    rm -f "$fixture_dir/github-snake.svg" \
      "$fixture_dir/github-snake-dark.svg" "$fixture_dir/unexpected.svg"
    if [[ -d "$fixture_dir" ]]; then
      rmdir "$fixture_dir"
    fi
  done
  rm -f "$tmp_root"/*.out
  if [[ -d "$tmp_root" ]]; then
    rmdir "$tmp_root"
  fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

safe_svg='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 24">
  <style>.dot{fill:#40c463;animation:pulse 2s linear infinite}@keyframes pulse{50%{opacity:.5}}</style>
  <rect class="dot" x="2" y="2" width="20" height="20" rx="4" />
  <rect class="dot" x="28" y="2" width="20" height="20" rx="4" />
</svg>'

write_pair() {
  fixture_dir="$1"
  mkdir -p "$fixture_dir"
  printf '%s\n' "$safe_svg" > "$fixture_dir/github-snake.svg"
  printf '%s\n' "$safe_svg" > "$fixture_dir/github-snake-dark.svg"
}

assert_rejected() {
  fixture_dir="$1"
  reason="$2"
  expected="$3"
  output="$tmp_root/${reason}.out"
  if bash "$checker" "$fixture_dir" >"$output" 2>&1; then
    printf 'snake-assets-test: expected rejection for %s\n' "$reason" >&2
    exit 1
  fi
  grep -Fq "snake-assets: $expected" "$output" \
    || { printf 'snake-assets-test: wrong rejection for %s\n' "$reason" >&2; exit 1; }
}

write_pair "$safe_dir"
bash "$checker" "$safe_dir" >"$tmp_root/safe.out" 2>&1
grep -Fqx 'snake-assets: ok (2 passive SVGs)' "$tmp_root/safe.out"

write_pair "$missing_dir"
unlink "$missing_dir/github-snake-dark.svg"

write_pair "$extra_dir"
printf '%s\n' "$safe_svg" > "$extra_dir/unexpected.svg"

write_pair "$script_dir_fixture"
printf '%s\n' "${safe_svg%</svg>}<script>alert(1)</script></svg>" \
  > "$script_dir_fixture/github-snake.svg"

write_pair "$foreign_dir"
printf '%s\n' "${safe_svg%</svg>}<foreignObject>text</foreignObject></svg>" \
  > "$foreign_dir/github-snake.svg"

write_pair "$event_dir"
printf '%s\n' "${safe_svg%</svg>}<rect onload=\"alert(1)\" /></svg>" \
  > "$event_dir/github-snake.svg"

write_pair "$external_dir"
printf '%s\n' "${safe_svg%</svg>}<image href=\"https://evil.example/x\" /></svg>" \
  > "$external_dir/github-snake.svg"

write_pair "$css_external_dir"
printf '%s\n' "${safe_svg%</svg>}<style>@import url(https://evil.example/x.css);</style></svg>" \
  > "$css_external_dir/github-snake.svg"

assert_rejected "$missing_dir" missing "expected exactly 2 asset entries"
assert_rejected "$extra_dir" extra "expected exactly 2 asset entries"
assert_rejected "$script_dir_fixture" script "active SVG content rejected"
assert_rejected "$foreign_dir" foreign-object "active SVG content rejected"
assert_rejected "$event_dir" event-handler "active SVG content rejected"
assert_rejected "$external_dir" external-reference "external SVG reference rejected"
assert_rejected "$css_external_dir" css-external-reference "external SVG reference rejected"

printf 'snake-assets-test: ok (1 safe + 7 rejected fixtures)\n'
```

- [ ] **Step 2: Run the validator suite to prove RED**

Run:

```bash
chmod +x scripts/test-check-snake-assets.sh
bash -n scripts/test-check-snake-assets.sh
bash scripts/test-check-snake-assets.sh
```

Expected: syntax passes, then execution exits non-zero because
`scripts/check-snake-assets.sh` does not exist.

- [ ] **Step 3: Implement the passive-SVG validator**

Create executable `scripts/check-snake-assets.sh` with this complete content:

```bash
#!/usr/bin/env bash

set -euo pipefail

asset_dir="${1:-dist}"

fail() {
  printf 'snake-assets: %s\n' "$*" >&2
  exit 1
}

[[ -d "$asset_dir" ]] || fail "asset directory not found: $asset_dir"

shopt -s nullglob dotglob
asset_entries=("$asset_dir"/*)
shopt -u nullglob dotglob

[[ "${#asset_entries[@]}" -eq 2 ]] \
  || fail "expected exactly 2 asset entries"

for entry in "${asset_entries[@]}"; do
  name="${entry##*/}"
  case "$name" in
    github-snake.svg|github-snake-dark.svg) ;;
    *) fail "unexpected asset entry: $name" ;;
  esac
  [[ -f "$entry" && ! -L "$entry" ]] \
    || fail "asset must be a regular non-symlink file: $name"
done

active_pattern='<(script|foreignobject|iframe|object|embed)([[:space:]>])|<!doctype|<!entity|javascript:|data:text/html|on[a-z]+[[:space:]]*='
external_reference_pattern="(href|xlink:href|src)[[:space:]]*=[[:space:]]*[\"']?[[:space:]]*(https?:|//|data:)|@import|url[[:space:]]*\\([[:space:]]*[\"']?[[:space:]]*(https?:|//|data:)"

for name in github-snake.svg github-snake-dark.svg; do
  path="$asset_dir/$name"
  size="$(wc -c < "$path" | tr -d ' ')"
  [[ "$size" -ge 100 && "$size" -le 2000000 ]] \
    || fail "SVG size outside allowed range: $name"

  head -c 512 "$path" | LC_ALL=C grep -Eiq '^[[:space:]]*<svg([[:space:]>])' \
    || fail "invalid SVG root: $name"
  tail -c 512 "$path" | LC_ALL=C grep -Eiq '</svg>[[:space:]]*$' \
    || fail "invalid SVG ending: $name"

  if LC_ALL=C grep -Eiq "$active_pattern" "$path"; then
    fail "active SVG content rejected: $name"
  fi
  if LC_ALL=C grep -Eiq "$external_reference_pattern" "$path"; then
    fail "external SVG reference rejected: $name"
  fi
done

printf 'snake-assets: ok (2 passive SVGs)\n'
```

- [ ] **Step 4: Run GREEN and validate the current remote snake artifacts**

Run:

```bash
bash -n scripts/check-snake-assets.sh
bash -n scripts/test-check-snake-assets.sh
bash scripts/test-check-snake-assets.sh
remote_assets="$(mktemp -d)"
git show origin/output:github-snake.svg > "$remote_assets/github-snake.svg"
git show origin/output:github-snake-dark.svg > "$remote_assets/github-snake-dark.svg"
bash scripts/check-snake-assets.sh "$remote_assets"
unlink "$remote_assets/github-snake.svg"
unlink "$remote_assets/github-snake-dark.svg"
rmdir "$remote_assets"
shellcheck scripts/check-snake-assets.sh scripts/test-check-snake-assets.sh
git diff --check
```

Expected: one safe and seven malicious fixtures behave correctly; both current
remote SVGs pass the same production validator.

- [ ] **Step 5: Commit the asset-validation boundary**

Run:

```bash
git add scripts/check-snake-assets.sh scripts/test-check-snake-assets.sh
git diff --cached --name-only
git diff --cached --check
git commit -m "test(profile): validate passive snake assets"
```

Expected staged paths: exactly the two new executable scripts.

---

### Task 2: Restore the visual layer and make it a tested profile contract

**Files:**
- Modify: `README.md:1-67`
- Modify: `scripts/check-profile.sh:15-142`
- Modify: `scripts/test-check-profile.sh:8-91`
- Modify: `docs/superpowers/specs/2026-08-30-proof-first-profile-design.md:1-8`

**Interfaces:**
- Consumes: the approved proof-first README, `CHECK_PROFILE_SKIP_NETWORK=1`, and the existing optional README-path argument.
- Produces: one four-badge hero row; one `Contribution trail` section; structural failures named `expected exactly 4 approved badges before Selected work`, `missing contribution snake URL`, `Contribution trail must be after Selected work and before More shipped`, and `banned retired asset reference`.

- [ ] **Step 1: Add the four new negative profile fixtures before changing the README or checker**

Extend `scripts/test-check-profile.sh` with four fixture paths and matching output cleanup:

```bash
missing_badges="$tmp_dir/missing-badges.md"
missing_snake_source="$tmp_dir/missing-snake-source.md"
misplaced_snake="$tmp_dir/misplaced-snake.md"
reintroduced_stats="$tmp_dir/reintroduced-stats.md"
```

Add these exact fixture transformations after the existing `unlinked_project`
fixture:

```bash
awk '!/img\.shields\.io|komarev\.com/' \
  "$repo_dir/README.md" >"$missing_badges"

awk '!/github-snake-dark\.svg/' \
  "$repo_dir/README.md" >"$missing_snake_source"

awk '
  $0 == "## Contribution trail" {
    print "## Contribution trail moved"
    next
  }
  $0 == "## More shipped" {
    print
    print ""
    print "## Contribution trail"
    next
  }
  { print }
' "$repo_dir/README.md" >"$misplaced_snake"

awk '
  $0 == "## Contact" {
    print "![Retired stats](https://raw.githubusercontent.com/Codevena/Codevena/output/stats.svg)"
    print ""
  }
  { print }
' "$repo_dir/README.md" >"$reintroduced_stats"
```

Add these exact assertions:

```bash
assert_rejected "$missing_badges" missing-badges \
  "expected exactly 4 approved badges before Selected work"
assert_rejected "$missing_snake_source" missing-snake-source \
  "missing contribution snake URL: https://raw.githubusercontent.com/Codevena/Codevena/output/github-snake-dark.svg"
assert_rejected "$misplaced_snake" misplaced-snake \
  "Contribution trail must be after Selected work and before More shipped"
assert_rejected "$reintroduced_stats" reintroduced-stats \
  "banned retired asset reference: stats.svg"
```

Update the success line to `profile-test: ok (8 negative fixtures rejected)`.

- [ ] **Step 2: Run the extended profile test to prove the current checker is RED**

Run:

```bash
bash -n scripts/test-check-profile.sh
bash scripts/test-check-profile.sh
```

Expected: Bash syntax passes, then the test exits `1` with
`profile-test: expected rejection for missing-badges` because the current
README contains no badges and the current checker does not require them.

- [ ] **Step 3: Restore the exact approved badge row and contribution section**

Insert this badge block after `` `Product to production. Edge to metal.` `` and
before the first horizontal rule:

```html
<p>
  <a href="https://codevena.dev"><img src="https://img.shields.io/badge/Portfolio-codevena.dev-7dcfff?style=flat-square&logo=googlechrome&logoColor=black" alt="Portfolio — codevena.dev" /></a>
  <img src="https://komarev.com/ghpvc/?username=Codevena&style=flat-square&color=7dcfff&label=Profile+views" alt="Profile views" />
  <a href="https://x.com/codevena"><img src="https://img.shields.io/badge/-@codevena-000000?style=flat-square&logo=x&logoColor=white" alt="X — @codevena" /></a>
  <a href="mailto:hello@codevena.dev"><img src="https://img.shields.io/badge/hello@codevena.dev-7dcfff?style=flat-square&logo=maildotru&logoColor=black" alt="Email — hello@codevena.dev" /></a>
</p>
```

Insert this block after the `Selected work` table and its horizontal rule, and
before `## More shipped`:

```html
## Contribution trail

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/Codevena/Codevena/output/github-snake-dark.svg" />
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/Codevena/Codevena/output/github-snake.svg" />
    <img alt="Animated contribution snake for Codevena's GitHub activity" src="https://raw.githubusercontent.com/Codevena/Codevena/output/github-snake.svg" />
  </picture>
</p>

---
```

Do not add `stats.svg`, `top-langs.svg`, a banner, or any other visual element.

- [ ] **Step 4: Implement the profile checker boundary**

Add `Contribution trail` to `required_headings`. Create temporary hero and
snake-section files alongside the existing temporary files and include all of
them in the exact cleanup trap.

Before the selected-work row checks, isolate the hero and enforce the four
approved badge lines:

```bash
hero_section_file="$(mktemp)"
snake_section_file="$(mktemp)"

awk -v heading="$selected_heading" '
  $0 == heading { exit }
  { print }
' "$readme_path" > "$hero_section_file"

badge_count="$(grep -Foc 'style=flat-square' "$hero_section_file" || true)"
[[ "$badge_count" -eq 4 ]] \
  || fail "expected exactly 4 approved badges before Selected work"

approved_badges=(
  '<a href="https://codevena.dev"><img src="https://img.shields.io/badge/Portfolio-codevena.dev-7dcfff?style=flat-square&logo=googlechrome&logoColor=black" alt="Portfolio — codevena.dev" /></a>'
  '<img src="https://komarev.com/ghpvc/?username=Codevena&style=flat-square&color=7dcfff&label=Profile+views" alt="Profile views" />'
  '<a href="https://x.com/codevena"><img src="https://img.shields.io/badge/-@codevena-000000?style=flat-square&logo=x&logoColor=white" alt="X — @codevena" /></a>'
  '<a href="mailto:hello@codevena.dev"><img src="https://img.shields.io/badge/hello@codevena.dev-7dcfff?style=flat-square&logo=maildotru&logoColor=black" alt="Email — hello@codevena.dev" /></a>'
)

for badge in "${approved_badges[@]}"; do
  badge_match_count="$(grep -Foc -- "$badge" "$hero_section_file" || true)"
  [[ "$badge_match_count" -eq 1 ]] \
    || fail "missing approved badge: $badge"
done
```

After the selected-work link checks, enforce heading count and placement, then
isolate the contribution section:

```bash
contribution_heading='## Contribution trail'
more_shipped_heading='## More shipped'
contribution_count="$(grep -Fxc -- "$contribution_heading" "$readme_path" || true)"
[[ "$contribution_count" -eq 1 ]] \
  || fail "Contribution trail heading must appear exactly once"

contribution_line="$(grep -Fnx -- "$contribution_heading" "$readme_path" | cut -d: -f1)"
more_shipped_line="$(grep -Fnx -- "$more_shipped_heading" "$readme_path" | cut -d: -f1)"
[[ "$selected_line" -lt "$contribution_line" && "$contribution_line" -lt "$more_shipped_line" ]] \
  || fail "Contribution trail must be after Selected work and before More shipped"

awk -v heading="$contribution_heading" '
  $0 == heading { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
' "$readme_path" > "$snake_section_file"

light_snake='https://raw.githubusercontent.com/Codevena/Codevena/output/github-snake.svg'
dark_snake='https://raw.githubusercontent.com/Codevena/Codevena/output/github-snake-dark.svg'
light_count="$(grep -Foc -- "$light_snake" "$snake_section_file" || true)"
dark_count="$(grep -Foc -- "$dark_snake" "$snake_section_file" || true)"
[[ "$light_count" -eq 2 ]] || fail "missing contribution snake URL: $light_snake"
[[ "$dark_count" -eq 1 ]] || fail "missing contribution snake URL: $dark_snake"
grep -Fq "alt=\"Animated contribution snake for Codevena's GitHub activity\"" "$snake_section_file" \
  || fail "missing approved contribution snake alt text"
```

Replace the banned-term array with exactly:

```bash
banned_terms=(
  "stats.svg"
  "top-langs.svg"
  "assets/banner.jpg"
)
```

Change its failure message to `banned retired asset reference: $term`.

- [ ] **Step 5: Record which earlier design clauses are superseded**

Add this note immediately below the metadata in
`docs/superpowers/specs/2026-08-30-proof-first-profile-design.md`:

```markdown
> **Partially superseded:**
> `docs/superpowers/specs/2026-08-30-visual-proof-snake-design.md` restores the
> approved badge row and contribution snake with a separated, pinned publish
> boundary. The proof-first content hierarchy and all factual-claim constraints
> in this document remain authoritative.
```

- [ ] **Step 6: Run GREEN checks for the visual contract**

Run:

```bash
bash -n scripts/check-profile.sh
bash -n scripts/test-check-profile.sh
bash scripts/test-check-profile.sh
CHECK_PROFILE_SKIP_NETWORK=1 bash scripts/check-profile.sh
bash scripts/check-profile.sh
shellcheck scripts/check-profile.sh scripts/test-check-profile.sh
git diff --check
```

Expected: eight negative fixtures are rejected, structure-only mode passes,
the live-link count is positive, and both shell scripts are clean.

- [ ] **Step 7: Commit the tested visual layer**

Run:

```bash
git add README.md scripts/check-profile.sh scripts/test-check-profile.sh \
  docs/superpowers/specs/2026-08-30-proof-first-profile-design.md
git diff --cached --name-only
git diff --cached --check
git commit -m "feat(profile): restore badges and contribution trail"
```

Expected staged paths: exactly the four listed files.

---

### Task 3: Add the split-permission snake workflow and automation guard

**Files:**
- Create: `.github/workflows/contribution-snake.yml`
- Create: `scripts/check-automation.sh`
- Create: `scripts/test-check-automation.sh`
- Modify: `.github/workflows/profile-check.yml:23-52`

**Interfaces:**
- Consumes: `scripts/check-snake-assets.sh`; the four verified action SHAs; existing remote branch `output`.
- Produces: artifact `contribution-snake-${{ github.run_id }}`; allowed output paths `github-snake.svg` and `github-snake-dark.svg`; repository check output `automation-check: ok`.

- [ ] **Step 1: Run the required pre-patch security investigation**

Before creating any workflow file, dispatch one fresh read-only security
investigator with only this assignment:

```text
Repository: /Users/markus/Developer/codevena-github-profile
Proposed boundary: a read-only Platane/snk generation job uploads two validated SVGs; a separate contents:write job using only pinned official GitHub actions revalidates and pushes those two paths to output.
Trace every token, credential, artifact, executable-code, path traversal, trigger, and git-write boundary. Identify concrete ways third-party generator output or code could reach repository write authority, mutate main, overwrite output paths beyond the two SVGs, or bypass validation. Verify the current output branch contents and legitimate behavior. Do not edit, stage, commit, dispatch, push, or delegate. Separate facts, inferences, and unresolved GitHub-setting dependencies; cite exact proposed plan clauses and repository paths.
```

Reconcile each finding against the plan. Any confirmed CRITICAL/WARN changes the
plan before mutation; record a short delta rather than rewriting passed areas.

- [ ] **Step 2: Write the automation guard before the workflow exists**

Create executable `scripts/check-automation.sh`. It must:

1. require `.github/workflows/contribution-snake.yml`;
2. reject every `uses:` line that does not end in a 40-character SHA plus an
   optional version comment;
3. require exactly one `contents: write`, located at six-space job scope in
   `contribution-snake.yml`;
4. isolate the `generate` and `publish` job blocks with indentation-aware AWK;
5. require `contents: read` and the exact Platane pin only in `generate`;
6. permit only the exact checkout and download-artifact pins in `publish`;
7. require the exact staging command
   `git add -- github-snake.svg github-snake-dark.svg`;
8. require `git push origin HEAD:output`;
9. reject `pull_request_target`, `workflow_run`, `--force`, and `git push -f`.

Use these exact success/failure interfaces:

```text
automation-check: contribution-snake workflow missing
automation-check: every uses reference must use a full commit SHA
automation-check: expected exactly one contents: write
automation-check: contents: write must be job-scoped in contribution-snake.yml
automation-check: generate job must be read-only
automation-check: Platane/snk must run only in generate
automation-check: publish job may only use pinned checkout/download actions
automation-check: exact snake staging command missing
automation-check: exact output push missing
automation-check: dangerous workflow trigger or force push detected
automation-check: ok
```

Use this complete guard implementation:

```bash
#!/usr/bin/env bash

set -euo pipefail

workflow_dir="${1:-.github/workflows}"
snake_workflow="$workflow_dir/contribution-snake.yml"

fail() {
  printf 'automation-check: %s\n' "$*" >&2
  exit 1
}

[[ -d "$workflow_dir" ]] || fail "workflow directory missing"
[[ -f "$snake_workflow" ]] || fail "contribution-snake workflow missing"

uses_file="$(mktemp)"
writes_file="$(mktemp)"
generate_file="$(mktemp)"
publish_file="$(mktemp)"
publish_uses_file="$(mktemp)"
trap 'rm -f "$uses_file" "$writes_file" "$generate_file" "$publish_file" "$publish_uses_file"' EXIT

grep -R -h -E '^[[:space:]]*uses:' "$workflow_dir" > "$uses_file" \
  || fail "every uses reference must use a full commit SHA"
if grep -Ev '^[[:space:]]*uses:[[:space:]]*[[:alnum:]_.-]+/[[:alnum:]_.\/-]+@[0-9a-f]{40}([[:space:]]+#.*)?$' "$uses_file"; then
  fail "every uses reference must use a full commit SHA"
fi

grep -R -n -E '^[[:space:]]*contents:[[:space:]]*write([[:space:]]*#.*)?$' \
  "$workflow_dir" > "$writes_file" || true
write_count="$(wc -l < "$writes_file" | tr -d ' ')"
[[ "$write_count" -eq 1 ]] || fail "expected exactly one contents: write"
write_location="$(head -n 1 "$writes_file")"
[[ "$write_location" == *"contribution-snake.yml:"* && \
   "$write_location" == *":      contents: write" ]] \
  || fail "contents: write must be job-scoped in contribution-snake.yml"

extract_job() {
  job_name="$1"
  destination="$2"
  awk -v heading="  ${job_name}:" '
    $0 == heading { capture = 1 }
    capture && $0 ~ /^  [[:alnum:]_-]+:$/ && $0 != heading { exit }
    capture { print }
  ' "$snake_workflow" > "$destination"
}

extract_job generate "$generate_file"
extract_job publish "$publish_file"

grep -Fq '      contents: read' "$generate_file" \
  || fail "generate job must be read-only"
if grep -Fq 'contents: write' "$generate_file"; then
  fail "generate job must be read-only"
fi
grep -Fq 'uses: Platane/snk@d8f6715049803e982ee5ff501b6b9b7d5deeb09b # v3.5.0' \
  "$generate_file" || fail "Platane/snk must run only in generate"
snake_use_count="$(grep -R -h -F 'uses: Platane/snk@' "$workflow_dir" | wc -l | tr -d ' ')"
[[ "$snake_use_count" -eq 1 ]] || fail "Platane/snk must run only in generate"

grep -Fq '      contents: write' "$publish_file" \
  || fail "contents: write must be job-scoped in contribution-snake.yml"
if grep -Fq 'uses: Platane/snk@' "$publish_file"; then
  fail "Platane/snk must run only in generate"
fi

grep -E '^[[:space:]]*uses:' "$publish_file" > "$publish_uses_file" \
  || fail "publish job may only use pinned checkout/download actions"
while IFS= read -r use_line; do
  case "$use_line" in
    *'uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1'*) ;;
    *'uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1'*) ;;
    *) fail "publish job may only use pinned checkout/download actions" ;;
  esac
done < "$publish_uses_file"
[[ "$(grep -Fc 'uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1' "$publish_uses_file")" -eq 2 ]] \
  || fail "publish job may only use pinned checkout/download actions"
[[ "$(grep -Fc 'uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c' "$publish_uses_file")" -eq 1 ]] \
  || fail "publish job may only use pinned checkout/download actions"

if grep -R -Eq 'pull_request_target:|workflow_run:' "$workflow_dir" \
  || grep -Fq -- '--force' "$snake_workflow" \
  || grep -Eq 'git push[[:space:]]+-f([[:space:]]|$)' "$snake_workflow"; then
  fail "dangerous workflow trigger or force push detected"
fi

grep -Fq 'git add -- github-snake.svg github-snake-dark.svg' "$publish_file" \
  || fail "exact snake staging command missing"
grep -Fq 'git push origin HEAD:output' "$publish_file" \
  || fail "exact output push missing"

printf 'automation-check: ok\n'
```

- [ ] **Step 3: Run the automation guard to prove RED against the current repository**

Run:

```bash
chmod +x scripts/check-automation.sh
bash -n scripts/check-automation.sh
bash scripts/check-automation.sh
```

Expected: exit `1` with
`automation-check: contribution-snake workflow missing`.

- [ ] **Step 4: Create the exact split-permission workflow**

Create `.github/workflows/contribution-snake.yml` with:

```yaml
name: Refresh contribution snake

on:
  push:
    branches:
      - main
  schedule:
    - cron: "31 3 * * *"
  workflow_dispatch:

permissions: {}

concurrency:
  group: contribution-snake-output
  cancel-in-progress: false

jobs:
  generate:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Generate light and dark contribution snakes
        uses: Platane/snk@d8f6715049803e982ee5ff501b6b9b7d5deeb09b # v3.5.0
        with:
          github_user_name: Codevena
          github_token: ${{ github.token }}
          outputs: |
            dist/github-snake.svg
            dist/github-snake-dark.svg?palette=github-dark

      - name: Checkout validation scripts without persisted credentials
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          path: source
          persist-credentials: false

      - name: Validate generated SVG boundary
        run: bash source/scripts/check-snake-assets.sh dist

      - name: Upload validated snake artifact
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: contribution-snake-${{ github.run_id }}
          path: |
            dist/github-snake.svg
            dist/github-snake-dark.svg
          if-no-files-found: error
          retention-days: 1
          compression-level: 0

  publish:
    needs: generate
    permissions:
      contents: write
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout trusted validation scripts
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          path: source
          persist-credentials: false

      - name: Checkout output branch with publish credentials
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          ref: output
          path: output
          fetch-depth: 1

      - name: Download validated snake artifact
        uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
        with:
          name: contribution-snake-${{ github.run_id }}
          path: generated
          digest-mismatch: error

      - name: Revalidate and publish only the snake SVGs
        run: |
          bash source/scripts/check-snake-assets.sh generated
          cp generated/github-snake.svg output/github-snake.svg
          cp generated/github-snake-dark.svg output/github-snake-dark.svg
          cd output
          git add -- github-snake.svg github-snake-dark.svg
          if git diff --cached --quiet; then
            echo "Contribution snake is already current."
            exit 0
          fi
          staged_paths="$(git diff --cached --name-only | LC_ALL=C sort)"
          if printf '%s\n' "$staged_paths" \
            | grep -Ev '^(github-snake\.svg|github-snake-dark\.svg)$'; then
            echo "::error::Unexpected staged path"
            exit 1
          fi
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git commit -m "chore: refresh contribution snake"
          git push origin HEAD:output
```

- [ ] **Step 5: Complete the automation guard and mutation suite**

Finish `scripts/check-automation.sh` against the exact workflow above, then
create executable `scripts/test-check-automation.sh`.

The test suite must copy exactly `profile-check.yml` and
`contribution-snake.yml` into four separate task-scoped fixture directories and
assert these mutations fail with the stated interface:

| Fixture | Mutation | Expected message |
|---|---|---|
| `mutable-ref` | replace the checkout SHA with `v7` | `every uses reference must use a full commit SHA` |
| `extra-write` | append a second `contents: write` to the copied profile workflow | `expected exactly one contents: write` |
| `generator-in-publish` | inject the pinned Platane action into the publish steps | `publish job may only use pinned checkout/download actions` |
| `force-push` | replace the exact push with `git push --force origin HEAD:output` | `dangerous workflow trigger or force push detected` |

The suite first requires the unmodified repository workflows to pass. It may
clean up only its explicitly created workflow copies, captured output files,
fixture directories, and temporary root. Its success line is
`automation-test: ok (baseline + 4 rejected mutations)`.

Use this complete mutation-test structure:

```bash
#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH='' cd -- "$script_dir/.." && pwd)"
checker="$script_dir/check-automation.sh"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/automation-test.XXXXXX")"
mutable_dir="$tmp_root/mutable-ref"
write_dir="$tmp_root/extra-write"
publish_dir="$tmp_root/generator-in-publish"
force_dir="$tmp_root/force-push"
fixture_dirs=("$mutable_dir" "$write_dir" "$publish_dir" "$force_dir")

cleanup() {
  for fixture_dir in "${fixture_dirs[@]}"; do
    rm -f "$fixture_dir/.github/workflows/profile-check.yml" \
      "$fixture_dir/.github/workflows/contribution-snake.yml" \
      "$fixture_dir/.github/workflows/profile-check.yml.tmp" \
      "$fixture_dir/.github/workflows/contribution-snake.yml.tmp"
    if [[ -d "$fixture_dir/.github/workflows" ]]; then rmdir "$fixture_dir/.github/workflows"; fi
    if [[ -d "$fixture_dir/.github" ]]; then rmdir "$fixture_dir/.github"; fi
    if [[ -d "$fixture_dir" ]]; then rmdir "$fixture_dir"; fi
  done
  rm -f "$tmp_root"/*.out
  if [[ -d "$tmp_root" ]]; then rmdir "$tmp_root"; fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

seed_fixture() {
  fixture_dir="$1"
  mkdir -p "$fixture_dir/.github/workflows"
  cp "$repo_dir/.github/workflows/profile-check.yml" \
    "$fixture_dir/.github/workflows/profile-check.yml"
  cp "$repo_dir/.github/workflows/contribution-snake.yml" \
    "$fixture_dir/.github/workflows/contribution-snake.yml"
}

assert_rejected() {
  fixture_dir="$1"
  reason="$2"
  expected="$3"
  output="$tmp_root/${reason}.out"
  if bash "$checker" "$fixture_dir/.github/workflows" >"$output" 2>&1; then
    printf 'automation-test: expected rejection for %s\n' "$reason" >&2
    exit 1
  fi
  grep -Fq "automation-check: $expected" "$output" \
    || { printf 'automation-test: wrong rejection for %s\n' "$reason" >&2; exit 1; }
}

bash "$checker" >"$tmp_root/baseline.out" 2>&1
grep -Fqx 'automation-check: ok' "$tmp_root/baseline.out"

seed_fixture "$mutable_dir"
awk '{ gsub("3d3c42e5aac5ba805825da76410c181273ba90b1", "v7"); print }' \
  "$mutable_dir/.github/workflows/profile-check.yml" \
  > "$mutable_dir/.github/workflows/profile-check.yml.tmp"
mv "$mutable_dir/.github/workflows/profile-check.yml.tmp" \
  "$mutable_dir/.github/workflows/profile-check.yml"

seed_fixture "$write_dir"
printf '\nfixture:\n  permissions:\n    contents: write\n' \
  >> "$write_dir/.github/workflows/profile-check.yml"

seed_fixture "$publish_dir"
awk '
  $0 == "  publish:" { in_publish = 1 }
  in_publish && $0 == "    steps:" {
    print
    print "      - name: Unsafe fixture generator"
    print "        uses: Platane/snk@d8f6715049803e982ee5ff501b6b9b7d5deeb09b # v3.5.0"
    in_publish = 0
    next
  }
  { print }
' "$publish_dir/.github/workflows/contribution-snake.yml" \
  > "$publish_dir/.github/workflows/contribution-snake.yml.tmp"
mv "$publish_dir/.github/workflows/contribution-snake.yml.tmp" \
  "$publish_dir/.github/workflows/contribution-snake.yml"

seed_fixture "$force_dir"
awk '{ gsub("git push origin HEAD:output", "git push --force origin HEAD:output"); print }' \
  "$force_dir/.github/workflows/contribution-snake.yml" \
  > "$force_dir/.github/workflows/contribution-snake.yml.tmp"
mv "$force_dir/.github/workflows/contribution-snake.yml.tmp" \
  "$force_dir/.github/workflows/contribution-snake.yml"

assert_rejected "$mutable_dir" mutable-ref \
  "every uses reference must use a full commit SHA"
assert_rejected "$write_dir" extra-write \
  "expected exactly one contents: write"
assert_rejected "$publish_dir" generator-in-publish \
  "publish job may only use pinned checkout/download actions"
assert_rejected "$force_dir" force-push \
  "dangerous workflow trigger or force push detected"

printf 'automation-test: ok (baseline + 4 rejected mutations)\n'
```

- [ ] **Step 6: Wire every repository-owned check into read-only CI**

Add these steps to `.github/workflows/profile-check.yml` after the existing
profile regression step and before installing actionlint:

```yaml
      - name: Validate passive snake asset fixtures
        run: bash scripts/test-check-snake-assets.sh

      - name: Validate automation security boundary
        run: bash scripts/check-automation.sh

      - name: Validate automation rejection fixtures
        run: bash scripts/test-check-automation.sh
```

Keep its top-level `permissions: contents: read` unchanged.

- [ ] **Step 7: Run the focused workflow security gate**

Run sequentially:

```bash
bash -n scripts/check-automation.sh
bash -n scripts/test-check-automation.sh
bash scripts/check-automation.sh
bash scripts/test-check-automation.sh
actionlint
shellcheck scripts/check-automation.sh scripts/test-check-automation.sh
if grep -R -n -E 'uses:.*@(v[0-9]+|main|master)([[:space:]]|$)' .github/workflows; then
  exit 1
fi
test "$(grep -R -h -E '^[[:space:]]*contents:[[:space:]]*write([[:space:]]*#.*)?$' .github/workflows | wc -l | tr -d ' ')" -eq 1
git diff --check
```

Expected: baseline plus four malicious mutations behave correctly, actionlint
and ShellCheck pass, no mutable ref exists, and exactly one write permission is
present.

- [ ] **Step 8: Commit the split automation boundary**

Run:

```bash
git add .github/workflows/contribution-snake.yml \
  .github/workflows/profile-check.yml \
  scripts/check-automation.sh scripts/test-check-automation.sh
git diff --cached --name-only
git diff --cached --check
git commit -m "ci(profile): publish contribution snake through split trust jobs"
```

Expected staged paths: exactly the four listed files; repository hooks report
no secret finding.

---

### Task 4: Independent review, final verification, and durable context

**Files:**
- Modify only for confirmed review findings: files changed in Tasks 1-3
- Modify: `/Users/markus/Documents/Brain/02 Projekte/Archiv/codevena-github-profile.md`
- Modify: `/Users/markus/Documents/Brain/05 Daily Notes/2026-08-30.md`

**Interfaces:**
- Consumes: complete diff from the pre-feature commit, output-branch tree, all repository-native checks.
- Produces: independently approved permission boundary and visual hierarchy, updated canonical context, and an integration-ready clean branch.

- [ ] **Step 1: Run a post-implementation bypass review**

Dispatch a fresh read-only security reviewer with only the candidate diff and
this assignment:

```text
Finding boundary: contribution snake requires an output-branch writer, but third-party generator code must never obtain write authority. Review the candidate diff for token exposure, persisted credentials, artifact/path traversal, active SVG content, mutable execution, unsafe triggers, unexpected staged paths, force-push behavior, TOCTOU gaps, and loss of legitimate animation. Do not edit, stage, commit, dispatch, push, or delegate. Report only source-backed CRITICAL/WARN bypasses with reproduction steps and a one-sentence minimal fix; say CLEAN if none exist.
```

Reproduce every claim before fixing. Resume the responsible implementer for
confirmed fixes, rerun the focused gate, and ask the same reviewer to inspect
only the findings delta.

- [ ] **Step 2: Run an independent public-interface review**

Dispatch a separate fresh read-only reviewer:

```text
Review the candidate GitHub profile against docs/superpowers/specs/2026-08-30-visual-proof-snake-design.md. Check that the primary CTA and three selected proofs remain dominant; exactly four approved badges are readable and accessible; Contribution trail is placed after Selected work; light/dark snake markup is correct; stats/top-language cards remain absent; claims and rights language are unchanged; Markdown heading and mobile layout are sound. Do not edit, stage, commit, dispatch, push, or delegate. Report only CRITICAL/WARN findings with evidence and minimal fixes; say APPROVED if none exist.
```

- [ ] **Step 3: Run the complete unchanged-tree gate**

Run sequentially:

```bash
bash -n scripts/check-profile.sh
bash -n scripts/test-check-profile.sh
bash -n scripts/check-snake-assets.sh
bash -n scripts/test-check-snake-assets.sh
bash -n scripts/check-automation.sh
bash -n scripts/test-check-automation.sh
bash scripts/test-check-profile.sh
bash scripts/test-check-snake-assets.sh
bash scripts/check-automation.sh
bash scripts/test-check-automation.sh
CHECK_PROFILE_SKIP_NETWORK=1 bash scripts/check-profile.sh
bash scripts/check-profile.sh
actionlint
shellcheck scripts/*.sh
git diff --check
test -z "$(git status --short)"
scan_report_path="$(mktemp)"
gitleaks git . --redact=100 --no-banner \
  --report-format json --report-path "$scan_report_path" >/dev/null 2>&1
test "$(jq -r 'length' "$scan_report_path")" -eq 0
unlink "$scan_report_path"
```

Expected: all six scripts pass syntax; profile reports eight rejected fixtures
and a positive live-link count; asset validation reports one safe plus seven
rejected fixtures; automation reports a clean baseline plus four rejected
mutations; actionlint, ShellCheck, diff, status, and Gitleaks are clean.

- [ ] **Step 4: Update the canonical archived Brain note with the completed reversal**

After every repository gate and review is clean, append this milestone to
`/Users/markus/Documents/Brain/02 Projekte/Archiv/codevena-github-profile.md`
without changing `status: archiviert` or adding open work:

```markdown
### 30.08.2026 — Visuelle Proof-Ebene zurückgebracht

- Proof-first-Hierarchie und die drei Hauptbeweise bleiben bestehen; die vier
  kompakten Portfolio-, Profilaufruf-, X- und E-Mail-Badges sind wieder sichtbar.
- Die animierte Contribution Snake ist für Light und Dark Mode zurück. Stats-
  und Top-Languages-Karten bleiben bewusst draußen.
- Der notwendige `output`-Writer ist sicherheitstechnisch geteilt: Der
  SHA-gepinnte Drittanbieter-Generator läuft read-only, nur ein separater Job
  mit offiziellen gepinnten Actions darf zwei validierte passive SVGs
  veröffentlichen.
- Abschluss: Negativfixtures, SVG-Validierung, Action-Pinning, actionlint,
  ShellCheck, Live-Linkcheck, Gitleaks und unabhängige Reviews bestanden.
```

- [ ] **Step 5: Add the material result to the current Daily Note**

Append to `/Users/markus/Documents/Brain/05 Daily Notes/2026-08-30.md`:

```markdown
## Codevena GitHub-Profil — visuelle Ebene sicher restauriert

Das Proof-first-Profil hat seine visuelle Identität zurück: vier kompakte
Badges und die animierte Contribution Snake ergänzen wieder die drei zentralen
Arbeitsbeweise. Die Snake-Erzeugung ist von der eng begrenzten
`output`-Veröffentlichung getrennt; der Drittanbieter-Generator erhält kein
Schreibrecht. Technische Evidenz und Sicherheitsgrenze stehen in
[[codevena-github-profile]].
```

- [ ] **Step 6: Inspect the final handoff state without mutating GitHub**

Run:

```bash
git log --oneline --decorate -8
git status --short --branch
git ls-files
git ls-tree -r --name-only origin/output
```

Expected: the feature branch is clean; `output` still contains the two snake
SVGs and retains the two unreferenced stats files; no push, workflow dispatch,
output mutation, deployment, or GitHub account change occurred during local
implementation.
