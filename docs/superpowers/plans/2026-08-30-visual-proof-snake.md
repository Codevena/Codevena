# Visual Proof Profile and Contribution Snake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the approved badge row and an automatically refreshed light/dark contribution snake while preserving the proof-first profile and isolating repository write permission from the third-party generator.

**Architecture:** README presentation and repository-native validation stay in the existing profile boundary. A parsed, namespace-aware XML allowlist accepts only two bounded passive SVG files with the observed Platane element and CSS grammar. A dedicated two-job workflow generates those files with read permission, transfers them through pinned official artifact actions, then lets a separate publisher update only the two allowed paths on `output` with job-scoped write permission.

**Tech Stack:** GitHub-flavored Markdown and HTML, Bash 3.2+, Python 3 standard library, GitHub Actions, Platane/snk v3.5.0, official GitHub checkout/upload/download actions, actionlint, ShellCheck, curl, Gitleaks

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
- Create: `scripts/check-snake-assets.py`
- Create: `scripts/test-check-snake-assets.sh`

**Interfaces:**
- Consumes: an optional directory argument, defaulting to `dist`.
- Produces: exit `0` only for a directory containing exactly two regular, non-symlink SVG files named `github-snake.svg` and `github-snake-dark.svg`, both conforming to the generated-snake XML allowlist; prints `snake-assets: ok (2 passive SVGs)` on success.
- Runtime: Python 3 standard library only. XML parsing is well-formed and namespace-aware; declarations and processing instructions are rejected before parsing, so no external entity is resolved.

- [ ] **Step 1: Write the validator regression suite first**

Create executable `scripts/test-check-snake-assets.sh`. It must create a
task-scoped temporary root for one safe pair and sixteen rejected mutations.
In addition to missing/extra entry, active element, event-handler, direct
external reference, and CSS import fixtures, it must cover a symlink,
malformed XML, `<s:script xmlns:s="http://www.w3.org/2000/svg">`,
`href="jav&#x61;script:alert(1)"`, `url(/external.svg)`,
`u\\72l(https://evil.example/x)`, and an external entity declaration.
It must also encode a document as UTF-16 containing
`<?xml-stylesheet href="https://evil.example/x.css"?>`.

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
| `symlink` | replace one approved file with a symlink | `regular non-symlink file` |
| `malformed` | truncate the closing SVG tag | `invalid XML` |
| `namespaced-script` | add `<s:script xmlns:s="http://www.w3.org/2000/svg">` | `active SVG content rejected` |
| `encoded-scheme` | add `<image href="jav&#x61;script:alert(1)" />` | `external SVG reference rejected` |
| `relative-css-url` | add `<style>.x{fill:url(/external.svg)}</style>` | `external SVG reference rejected` |
| `escaped-css-url` | add CSS `u\\72l(https://evil.example/x)` | `external SVG reference rejected` |
| `external-entity` | add a `DOCTYPE`/external `ENTITY` declaration | `active SVG content rejected` |
| `utf16-processing-instruction` | encode an XML-stylesheet PI document as UTF-16 | `SVG must be UTF-8 without BOM` |
| `utf8-bom` | prefix the otherwise safe SVG with a real UTF-8 BOM | `SVG must be UTF-8 without BOM` |

Cleanup may remove only the explicitly named files, captured outputs, fixture
directories, and temporary root created by the test. The success line is
`snake-assets-test: ok (1 safe + 16 rejected fixtures)`.

Use this base structure and expand its declarations, cleanup list, fixture
construction, and `assert_rejected` calls for every row in the table:

```bash
#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
checker="$script_dir/check-snake-assets.py"
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
  if python3 "$checker" "$fixture_dir" >"$output" 2>&1; then
    printf 'snake-assets-test: expected rejection for %s\n' "$reason" >&2
    exit 1
  fi
  grep -Fq "snake-assets: $expected" "$output" \
    || { printf 'snake-assets-test: wrong rejection for %s\n' "$reason" >&2; exit 1; }
}

write_pair "$safe_dir"
python3 "$checker" "$safe_dir" >"$tmp_root/safe.out" 2>&1
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

# Expand this base at implementation time: construct and assert all sixteen
# rejected fixtures here. This comment must not remain in the committed test.
printf 'snake-assets-test: ok (1 safe + 16 rejected fixtures)\n'
```

- [ ] **Step 2: Run the validator suite to prove RED**

Run:

```bash
chmod +x scripts/test-check-snake-assets.sh
/bin/bash -n scripts/test-check-snake-assets.sh
/bin/bash scripts/test-check-snake-assets.sh
```

Expected: syntax passes, then execution exits non-zero because
`scripts/check-snake-assets.py` does not exist.

- [ ] **Step 3: Implement the parsed XML allowlist**

Create executable `scripts/check-snake-assets.py` with this complete content:

```python
#!/usr/bin/env python3

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SVG_NS = "http://www.w3.org/2000/svg"
APPROVED_NAMES = {"github-snake.svg", "github-snake-dark.svg"}
ALLOWED_ELEMENTS = {"svg", "style", "desc", "rect"}
ALLOWED_ATTRIBUTES = {"viewBox", "width", "height", "class", "x", "y", "rx", "ry"}
ALLOWED_CSS_AT_RULES = {"keyframes"}
ALLOWED_CSS_FUNCTIONS = {"var", "scale", "translate"}


def fail(message: str) -> None:
    print(f"snake-assets: {message}", file=sys.stderr)
    raise SystemExit(1)


def split_name(name: str) -> tuple[str, str]:
    if name.startswith("{"):
        namespace, local_name = name[1:].split("}", 1)
        return namespace, local_name
    return "", name


def validate_svg(path: Path) -> None:
    size = path.stat().st_size
    if not 100 <= size <= 2_000_000:
        fail(f"SVG size outside allowed range: {path.name}")

    raw = path.read_bytes()
    if raw.startswith((b"\xef\xbb\xbf", b"\xff\xfe", b"\xfe\xff")):
        fail(f"SVG must be UTF-8 without BOM: {path.name}")
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError:
        fail(f"SVG must be UTF-8 without BOM: {path.name}")

    lowered = text.casefold()
    if "<!doctype" in lowered or "<!entity" in lowered or "<?" in text:
        fail(f"active SVG content rejected: {path.name}")

    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        fail(f"invalid XML: {path.name}")

    root_namespace, root_name = split_name(root.tag)
    if root_namespace != SVG_NS or root_name != "svg":
        fail(f"invalid SVG root: {path.name}")

    for element in root.iter():
        namespace, local_name = split_name(element.tag)

        for attribute_name in element.attrib:
            attribute_namespace, attribute_local_name = split_name(attribute_name)
            lowered_attribute = attribute_local_name.casefold()
            if lowered_attribute in {"href", "src"}:
                fail(f"external SVG reference rejected: {path.name}")
            if lowered_attribute.startswith("on"):
                fail(f"active SVG content rejected: {path.name}")
            if attribute_namespace or attribute_local_name not in ALLOWED_ATTRIBUTES:
                fail(f"active SVG content rejected: {path.name}")

        if namespace != SVG_NS or local_name not in ALLOWED_ELEMENTS:
            fail(f"active SVG content rejected: {path.name}")

        if local_name not in {"style", "desc"} and (element.text or "").strip():
            fail(f"active SVG content rejected: {path.name}")
        if (element.tail or "").strip():
            fail(f"active SVG content rejected: {path.name}")

        if local_name == "style":
            css = "".join(element.itertext())
            if "\\" in css or "/*" in css or "*/" in css:
                fail(f"external SVG reference rejected: {path.name}")
            at_rules = {value.casefold() for value in re.findall(r"@([A-Za-z_-]+)", css)}
            functions = {
                value.casefold()
                for value in re.findall(r"([A-Za-z_-]+)\s*\(", css)
            }
            if not at_rules <= ALLOWED_CSS_AT_RULES:
                fail(f"external SVG reference rejected: {path.name}")
            if not functions <= ALLOWED_CSS_FUNCTIONS:
                fail(f"external SVG reference rejected: {path.name}")


asset_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "dist")
if not asset_dir.is_dir():
    fail(f"asset directory not found: {asset_dir}")

entries = list(asset_dir.iterdir())
if len(entries) != 2:
    fail("expected exactly 2 asset entries")

if {entry.name for entry in entries} != APPROVED_NAMES:
    unexpected = sorted(entry.name for entry in entries if entry.name not in APPROVED_NAMES)
    fail(f"unexpected asset entry: {unexpected[0]}")

for entry in entries:
    if entry.is_symlink() or not entry.is_file():
        fail(f"asset must be a regular non-symlink file: {entry.name}")

for name in sorted(APPROVED_NAMES):
    validate_svg(asset_dir / name)

print("snake-assets: ok (2 passive SVGs)")
```

This boundary is deliberately stricter than a general sanitizer. It accepts
the deployed Platane grammar, including `@keyframes`, while rejecting every
link-bearing element or attribute, all CSS resource functions, XML
declarations, entities, namespace tricks, and CSS escape/comment obfuscation.

- [ ] **Step 4: Run GREEN and validate the current remote snake artifacts**

Run:

```bash
/bin/bash -n scripts/test-check-snake-assets.sh
/bin/bash scripts/test-check-snake-assets.sh
remote_assets="$(mktemp -d)"
git show origin/output:github-snake.svg > "$remote_assets/github-snake.svg"
git show origin/output:github-snake-dark.svg > "$remote_assets/github-snake-dark.svg"
python3 scripts/check-snake-assets.py "$remote_assets"
unlink "$remote_assets/github-snake.svg"
unlink "$remote_assets/github-snake-dark.svg"
rmdir "$remote_assets"
shellcheck scripts/test-check-snake-assets.sh
git diff --check
```

Expected: one safe and sixteen malicious fixtures behave correctly; both current
remote SVGs pass the same production validator.

- [ ] **Step 5: Commit the asset-validation boundary**

Run:

```bash
git add scripts/check-snake-assets.py scripts/test-check-snake-assets.sh
git diff --cached --name-only
git diff --cached --check
git commit -m "test(profile): validate passive snake assets"
```

Expected staged paths: exactly the Python validator and Bash regression suite.

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

- [ ] **Step 1: Add five new negative profile fixtures before changing the README or checker**

Extend `scripts/test-check-profile.sh` with five fixture paths and matching output cleanup:

```bash
missing_badges="$tmp_dir/missing-badges.md"
missing_snake_source="$tmp_dir/missing-snake-source.md"
misplaced_snake="$tmp_dir/misplaced-snake.md"
reintroduced_stats="$tmp_dir/reintroduced-stats.md"
extra_badge="$tmp_dir/extra-badge.md"
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

awk '
  $0 == "</p>" && !injected {
    print "  <IMG src=\"https://example.invalid/extra.svg\" alt=\"Extra badge\" />"
    injected = 1
  }
  { print }
' "$repo_dir/README.md" >"$extra_badge"
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
assert_rejected "$extra_badge" extra-badge \
  "expected exactly 4 approved badges before Selected work"
```

Update the success line to `profile-test: ok (9 negative fixtures rejected)`.

- [ ] **Step 2: Run the extended profile test to prove the current checker is RED**

Run:

```bash
/bin/bash -n scripts/test-check-profile.sh
/bin/bash scripts/test-check-profile.sh
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

badge_count="$(awk '
  {
    line = tolower($0)
    while (match(line, /<img([[:space:]>])/)) {
      count++
      line = substr(line, RSTART + RLENGTH)
    }
  }
  END { print count + 0 }
' "$hero_section_file")"
if grep -Eq '!\[[^]]*\]\(' "$hero_section_file"; then
  fail "expected exactly 4 approved badges before Selected work"
fi
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
/bin/bash -n scripts/check-profile.sh
/bin/bash -n scripts/test-check-profile.sh
/bin/bash scripts/test-check-profile.sh
CHECK_PROFILE_SKIP_NETWORK=1 /bin/bash scripts/check-profile.sh
/bin/bash scripts/check-profile.sh
shellcheck scripts/check-profile.sh scripts/test-check-profile.sh
git diff --check
```

Expected: nine negative fixtures are rejected, structure-only mode passes,
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
- Consumes: `scripts/check-snake-assets.py`; the four verified action SHAs; existing remote branch `output`.
- Produces: artifact `contribution-snake-${{ github.run_id }}-${{ github.run_attempt }}`; allowed output paths `github-snake.svg` and `github-snake-dark.svg`; repository check output `automation-check: ok`.

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
3. reject `write-all`, inline permission maps, and every `*: write` outside the
   one exact six-space `contents: write` publisher entry;
4. isolate the `generate` and `publish` job blocks with indentation-aware AWK;
5. require the exact permission blocks: top-level `{}`, generate-only
   `contents: read`, publish-only `contents: write`, and the existing profile
   workflow's top-level `contents: read`—with no additional permission key;
6. permit only the exact checkout and download-artifact pins in `publish`;
7. require the exact staging command
   `git add -- github-snake.svg github-snake-dark.svg`;
8. require `git push origin HEAD:output`;
9. reject `pull_request_target`, `workflow_run`, `--force`, and `git push -f`.

Use these exact success/failure interfaces:

```text
automation-check: contribution-snake workflow missing
automation-check: every uses reference must use a full commit SHA
automation-check: workflow permissions must match exact allowlist
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
profile_workflow="$workflow_dir/profile-check.yml"

fail() {
  printf 'automation-check: %s\n' "$*" >&2
  exit 1
}

[[ -d "$workflow_dir" ]] || fail "workflow directory missing"
[[ -f "$snake_workflow" ]] || fail "contribution-snake workflow missing"
[[ -f "$profile_workflow" ]] || fail "profile-check workflow missing"

uses_file="$(mktemp)"
writes_file="$(mktemp)"
generate_file="$(mktemp)"
publish_file="$(mktemp)"
publish_uses_file="$(mktemp)"
generate_permissions_file="$(mktemp)"
publish_permissions_file="$(mktemp)"
profile_permissions_file="$(mktemp)"
trap 'rm -f "$uses_file" "$writes_file" "$generate_file" "$publish_file" "$publish_uses_file" "$generate_permissions_file" "$publish_permissions_file" "$profile_permissions_file"' EXIT

grep -R -h -E '^[[:space:]]*uses:' "$workflow_dir" > "$uses_file" \
  || fail "every uses reference must use a full commit SHA"
if grep -Ev '^[[:space:]]*uses:[[:space:]]*[[:alnum:]_.-]+/[[:alnum:]_.\/-]+@[0-9a-f]{40}([[:space:]]+#.*)?$' "$uses_file"; then
  fail "every uses reference must use a full commit SHA"
fi

if grep -R -n -Ei '^[[:space:]]*permissions:[[:space:]]+[^#[:space:]].*$' \
  "$workflow_dir" | grep -Ev 'permissions:[[:space:]]*\{\}[[:space:]]*(#.*)?$'; then
  fail "workflow permissions must match exact allowlist"
fi

grep -R -n -Ei '^[[:space:]]*[[:alnum:]_-]+:[[:space:]]*write([[:space:]]*#.*)?$' \
  "$workflow_dir" > "$writes_file" || true
write_count="$(wc -l < "$writes_file" | tr -d ' ')"
[[ "$write_count" -eq 1 ]] \
  || fail "workflow permissions must match exact allowlist"
write_location="$(head -n 1 "$writes_file")"
[[ "$write_location" == *"contribution-snake.yml:"* && \
   "$write_location" == *":      contents: write" ]] \
  || fail "workflow permissions must match exact allowlist"

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

extract_job_permissions() {
  job_file="$1"
  destination="$2"
  awk '
    $0 == "    permissions:" { capture = 1 }
    capture && $0 ~ /^    [^ ]/ && $0 != "    permissions:" { exit }
    capture { print }
  ' "$job_file" > "$destination"
}

extract_job_permissions "$generate_file" "$generate_permissions_file"
extract_job_permissions "$publish_file" "$publish_permissions_file"
awk '
  $0 == "permissions:" { capture = 1 }
  capture && $0 ~ /^[^ ]/ && $0 != "permissions:" { exit }
  capture { print }
' "$profile_workflow" > "$profile_permissions_file"

[[ "$(grep -Ec '^[[:space:]]*permissions:' "$snake_workflow")" -eq 3 ]] \
  || fail "workflow permissions must match exact allowlist"
[[ "$(grep -Fxc 'permissions: {}' "$snake_workflow")" -eq 1 ]] \
  || fail "workflow permissions must match exact allowlist"
[[ "$(<"$profile_permissions_file")" == $'permissions:\n  contents: read' ]] \
  || fail "workflow permissions must match exact allowlist"
[[ "$(<"$generate_permissions_file")" == $'    permissions:\n      contents: read' ]] \
  || fail "workflow permissions must match exact allowlist"
[[ "$(<"$publish_permissions_file")" == $'    permissions:\n      contents: write' ]] \
  || fail "workflow permissions must match exact allowlist"

grep -Fq 'uses: Platane/snk@d8f6715049803e982ee5ff501b6b9b7d5deeb09b # v3.5.0' \
  "$generate_file" || fail "Platane/snk must run only in generate"
snake_use_count="$(grep -R -h -F 'uses: Platane/snk@' "$workflow_dir" | wc -l | tr -d ' ')"
[[ "$snake_use_count" -eq 1 ]] || fail "Platane/snk must run only in generate"

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
/bin/bash -n scripts/check-automation.sh
/bin/bash scripts/check-automation.sh
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
        run: python3 source/scripts/check-snake-assets.py dist

      - name: Upload validated snake artifact
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: contribution-snake-${{ github.run_id }}-${{ github.run_attempt }}
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
          name: contribution-snake-${{ github.run_id }}-${{ github.run_attempt }}
          path: generated
          digest-mismatch: error

      - name: Revalidate and publish only the snake SVGs
        run: |
          python3 source/scripts/check-snake-assets.py generated
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
`contribution-snake.yml` into eight separate task-scoped fixture directories and
assert these mutations fail with the stated interface:

| Fixture | Mutation | Expected message |
|---|---|---|
| `mutable-ref` | replace the checkout SHA with `v7` | `every uses reference must use a full commit SHA` |
| `extra-write` | append a second `contents: write` to the copied profile workflow | `workflow permissions must match exact allowlist` |
| `write-all` | replace top-level `{}` with `write-all` | `workflow permissions must match exact allowlist` |
| `inline-write` | replace top-level `{}` with `{contents: write}` | `workflow permissions must match exact allowlist` |
| `generate-other-write` | add `issues: write` to the generate permission block | `workflow permissions must match exact allowlist` |
| `quoted-generate-write` | add `"issues": "write"` to the generate permission block | `workflow permissions must match exact allowlist` |
| `generator-in-publish` | inject the pinned Platane action into the publish steps | `Platane/snk must run only in generate` |
| `force-push` | replace the exact push with `git push --force origin HEAD:output` | `dangerous workflow trigger or force push detected` |

The suite first requires the unmodified repository workflows to pass. It may
clean up only its explicitly created workflow copies, captured output files,
fixture directories, and temporary root. Its success line is
`automation-test: ok (baseline + 8 rejected mutations)`.

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
write_all_dir="$tmp_root/write-all"
inline_write_dir="$tmp_root/inline-write"
generator_write_dir="$tmp_root/generate-other-write"
quoted_write_dir="$tmp_root/quoted-generate-write"
publish_dir="$tmp_root/generator-in-publish"
force_dir="$tmp_root/force-push"
fixture_dirs=(
  "$mutable_dir" "$write_dir" "$write_all_dir" "$inline_write_dir"
  "$generator_write_dir" "$quoted_write_dir" "$publish_dir" "$force_dir"
)

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

seed_fixture "$write_all_dir"
awk '{ sub(/^permissions: \{\}$/, "permissions: write-all"); print }' \
  "$write_all_dir/.github/workflows/contribution-snake.yml" \
  > "$write_all_dir/.github/workflows/contribution-snake.yml.tmp"
mv "$write_all_dir/.github/workflows/contribution-snake.yml.tmp" \
  "$write_all_dir/.github/workflows/contribution-snake.yml"

seed_fixture "$inline_write_dir"
awk '{ sub(/^permissions: \{\}$/, "permissions: {contents: write}"); print }' \
  "$inline_write_dir/.github/workflows/contribution-snake.yml" \
  > "$inline_write_dir/.github/workflows/contribution-snake.yml.tmp"
mv "$inline_write_dir/.github/workflows/contribution-snake.yml.tmp" \
  "$inline_write_dir/.github/workflows/contribution-snake.yml"

seed_fixture "$generator_write_dir"
awk '
  $0 == "      contents: read" && !injected {
    print
    print "      issues: write"
    injected = 1
    next
  }
  { print }
' "$generator_write_dir/.github/workflows/contribution-snake.yml" \
  > "$generator_write_dir/.github/workflows/contribution-snake.yml.tmp"
mv "$generator_write_dir/.github/workflows/contribution-snake.yml.tmp" \
  "$generator_write_dir/.github/workflows/contribution-snake.yml"

seed_fixture "$quoted_write_dir"
awk '
  $0 == "      contents: read" && !injected {
    print
    print "      \"issues\": \"write\""
    injected = 1
    next
  }
  { print }
' "$quoted_write_dir/.github/workflows/contribution-snake.yml" \
  > "$quoted_write_dir/.github/workflows/contribution-snake.yml.tmp"
mv "$quoted_write_dir/.github/workflows/contribution-snake.yml.tmp" \
  "$quoted_write_dir/.github/workflows/contribution-snake.yml"

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
  "workflow permissions must match exact allowlist"
assert_rejected "$write_all_dir" write-all \
  "workflow permissions must match exact allowlist"
assert_rejected "$inline_write_dir" inline-write \
  "workflow permissions must match exact allowlist"
assert_rejected "$generator_write_dir" generate-other-write \
  "workflow permissions must match exact allowlist"
assert_rejected "$quoted_write_dir" quoted-generate-write \
  "workflow permissions must match exact allowlist"
assert_rejected "$publish_dir" generator-in-publish \
  "Platane/snk must run only in generate"
assert_rejected "$force_dir" force-push \
  "dangerous workflow trigger or force push detected"

printf 'automation-test: ok (baseline + 8 rejected mutations)\n'
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
/bin/bash -n scripts/check-automation.sh
/bin/bash -n scripts/test-check-automation.sh
/bin/bash scripts/check-automation.sh
/bin/bash scripts/test-check-automation.sh
actionlint
shellcheck scripts/check-automation.sh scripts/test-check-automation.sh
if grep -R -n -E 'uses:.*@(v[0-9]+|main|master)([[:space:]]|$)' .github/workflows; then
  exit 1
fi
test "$(grep -R -h -E '^[[:space:]]*contents:[[:space:]]*write([[:space:]]*#.*)?$' .github/workflows | wc -l | tr -d ' ')" -eq 1
git diff --check
```

Expected: baseline plus eight malicious mutations behave correctly, actionlint
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

### Task 4: Independent review and local final verification

**Files:**
- Modify only for confirmed review findings: files changed in Tasks 1-3

**Interfaces:**
- Consumes: complete diff from the pre-feature commit, output-branch tree, all repository-native checks.
- Produces: independently approved permission boundary and visual hierarchy plus an integration-ready clean local branch. It makes no GitHub or Brain completion claim.

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

- [ ] **Step 3: Commit any confirmed review fixes before the clean-tree gate**

If either review produced confirmed fixes, stage only the exact changed Task 1–3
paths, inspect `git diff --cached --name-only` and `git diff --cached`, rerun the
focused checks, and commit them as:

```bash
git commit -m "fix(profile): address independent review findings"
```

Then give the same reviewer only the findings delta and direct side effects.
If no fix was needed, skip this commit. Do not enter the final gate with
uncommitted review changes.

- [ ] **Step 4: Run the complete unchanged-tree gate**

Run sequentially:

```bash
(
  set -euo pipefail
  scan_report_path="$(mktemp)"
  cleanup_scan_report() {
    if [[ -e "$scan_report_path" ]]; then
      unlink "$scan_report_path"
    fi
  }
  trap cleanup_scan_report EXIT
  trap 'exit 1' HUP INT TERM

  /bin/bash -n scripts/check-profile.sh
  /bin/bash -n scripts/test-check-profile.sh
  /bin/bash -n scripts/test-check-snake-assets.sh
  /bin/bash -n scripts/check-automation.sh
  /bin/bash -n scripts/test-check-automation.sh
  /bin/bash scripts/test-check-profile.sh
  /bin/bash scripts/test-check-snake-assets.sh
  /bin/bash scripts/check-automation.sh
  /bin/bash scripts/test-check-automation.sh
  CHECK_PROFILE_SKIP_NETWORK=1 /bin/bash scripts/check-profile.sh
  /bin/bash scripts/check-profile.sh
  actionlint
  shellcheck scripts/*.sh
  git diff --check
  test -z "$(git status --short)"
  gitleaks git . --redact=100 --no-banner \
    --report-format json --report-path "$scan_report_path" >/dev/null 2>&1
  test "$(jq -r 'length' "$scan_report_path")" -eq 0
)
```

Expected: all five Bash scripts pass under the macOS system Bash 3.2; profile
reports nine rejected fixtures and a positive live-link count; asset validation
reports one safe plus sixteen rejected fixtures; automation reports a clean
baseline plus eight rejected mutations; actionlint, ShellCheck, diff, status,
and Gitleaks are clean. Strict mode and the cleanup trap preserve every failing
exit status while still removing the temporary report.

- [ ] **Step 5: Inspect the local handoff state without mutating GitHub**

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

---

### Task 5: Approval-gated integration, live verification, and durable context

**Files:**
- Modify only after live success:
  `/Users/markus/Documents/Brain/02 Projekte/Archiv/codevena-github-profile.md`
- Modify only after live success:
  `/Users/markus/Documents/Brain/05 Daily Notes/2026-08-30.md`

**Interfaces:**
- Consumes: the clean reviewed local branch, explicit authorization from Markus
  to merge and push this new visual-snake change, and GitHub Actions/live state.
- Produces: verified `main`, a bounded `output` refresh, rollback evidence, and
  Brain notes that describe only the actually live milestone.

- [ ] **Step 1: Stop for a fresh external-mutation approval**

Report the local commit list and final gate evidence. Ask Markus explicitly for
permission to merge the visual-snake branch into local `main` and push it. The
earlier proof-first push authorization is already consumed and does not cover
this change. Do not merge, push, dispatch, or edit Brain completion notes until
that new approval is received.

- [ ] **Step 2: Capture recovery anchors, integrate, and push exactly `main`**

After approval, fetch without mutation and persist the recovery anchors in a
task-scoped, untracked file inside `.git`. Refuse to overwrite an existing
recovery file:

```bash
set -euo pipefail
recovery_file="$(git rev-parse --git-path codex-visual-snake-recovery.env)"
test ! -e "$recovery_file"
git fetch origin main output
pre_main_remote="$(git rev-parse origin/main)"
pre_output_remote="$(git rev-parse origin/output)"
stats_before="$(git rev-parse origin/output:stats.svg)"
top_langs_before="$(git rev-parse origin/output:top-langs.svg)"
for anchor in "$pre_main_remote" "$pre_output_remote" "$stats_before" "$top_langs_before"; do
  [[ "$anchor" =~ ^[0-9a-f]{40}$ ]]
done
printf 'PRE_MAIN_REMOTE=%s\nPRE_OUTPUT_REMOTE=%s\nSTATS_BEFORE=%s\nTOP_LANGS_BEFORE=%s\n' \
  "$pre_main_remote" "$pre_output_remote" "$stats_before" "$top_langs_before" \
  > "$recovery_file"
printf 'Recovery anchors: %s\n' "$recovery_file"
```

Merge the reviewed feature branch into local `main` using the already approved
integration shape, rerun Task 4 Step 4 on the unchanged merge result, inspect
the exact outgoing range, then push only `main`:

```bash
set -euo pipefail
recovery_file="$(git rev-parse --git-path codex-visual-snake-recovery.env)"
test -f "$recovery_file"
pre_main_remote="$(awk -F= '$1 == "PRE_MAIN_REMOTE" { print $2 }' \
  "$recovery_file")"
[[ "$pre_main_remote" =~ ^[0-9a-f]{40}$ ]]
git diff --stat "$pre_main_remote"..main
git log --oneline "$pre_main_remote"..main
integration_commit="$(git rev-parse main)"
[[ "$integration_commit" =~ ^[0-9a-f]{40}$ ]]
printf 'INTEGRATION_COMMIT=%s\n' "$integration_commit" \
  >> "$recovery_file"
git push origin main
```

- [ ] **Step 3: Verify both workflows and the bounded output mutation**

Wait for the exact `Validate GitHub profile` and
`Refresh contribution snake` runs for the persisted integration SHA. Require
both conclusions to be `success`; do not manually
dispatch a retry without separate authorization. Then fetch `output` and verify:

```bash
set -euo pipefail
recovery_file="$(git rev-parse --git-path codex-visual-snake-recovery.env)"
test -f "$recovery_file"
read_recovery_value() {
  awk -F= -v key="$1" '$1 == key { print $2 }' "$recovery_file"
}
pre_main_remote="$(read_recovery_value PRE_MAIN_REMOTE)"
pre_output_remote="$(read_recovery_value PRE_OUTPUT_REMOTE)"
stats_before="$(read_recovery_value STATS_BEFORE)"
top_langs_before="$(read_recovery_value TOP_LANGS_BEFORE)"
integration_commit="$(read_recovery_value INTEGRATION_COMMIT)"
for anchor in "$pre_main_remote" "$pre_output_remote" "$stats_before" \
  "$top_langs_before" "$integration_commit"; do
  [[ "$anchor" =~ ^[0-9a-f]{40}$ ]]
done
wait_for_run_id() {
  workflow_name="$1"
  attempts=0
  while [[ "$attempts" -lt 30 ]]; do
    run_id="$(gh run list --workflow "$workflow_name" \
      --commit "$integration_commit" --limit 20 --json databaseId \
      --jq '.[0].databaseId // empty')"
    if [[ -n "$run_id" ]]; then
      printf '%s\n' "$run_id"
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 10
  done
  return 1
}
profile_run_id="$(wait_for_run_id 'Validate GitHub profile')"
snake_run_id="$(wait_for_run_id 'Refresh contribution snake')"
gh run watch "$profile_run_id" --exit-status
gh run watch "$snake_run_id" --exit-status
git fetch origin main output
test "$(git rev-parse origin/main)" = "$integration_commit"
test "$(git rev-parse origin/output:stats.svg)" = "$stats_before"
test "$(git rev-parse origin/output:top-langs.svg)" = "$top_langs_before"
changed_output_paths="$(git diff-tree --no-commit-id --name-only -r \
  "$pre_output_remote"..origin/output | LC_ALL=C sort -u)"
test -n "$changed_output_paths"
if printf '%s\n' "$changed_output_paths" \
  | grep -Ev '^(github-snake\.svg|github-snake-dark\.svg)$'; then
  exit 1
fi
```

Run `python3 scripts/check-snake-assets.py` against the two fetched live blobs,
confirm the raw live README matches `origin/main:README.md`, and inspect the
public GitHub profile at desktop and narrow width for the four badges, dominant
proof-first CTA, three selected projects, light/dark picture markup, animated
snake, and absence of stats/top-language cards.

- [ ] **Step 4: Apply the approval-gated rollback rule if live verification fails**

Stop and report the failing workflow, live symptom, and every literal value
from the persisted recovery file plus the changed paths. Do not
silently retry or rewrite history. With a new explicit rollback approval,
revert the persisted `INTEGRATION_COMMIT`
on `main` and push the revert. If `output` itself must be restored, publish a
new recovery commit containing the two snake blobs from `pre_output_remote`;
never force-push or delete the branch. Re-run the same live checks after any
approved recovery.

- [ ] **Step 5: Update Brain only after live success**

Read `/Users/markus/Documents/Brain/CLAUDE.md` completely before the vault edit.
Keep the canonical archived note's status unchanged and add no open task. Add
this concise milestone to the project note:

```markdown
### 30.08.2026 — Visuelle Proof-Ebene live zurückgebracht

- Proof-first-Hierarchie und drei Hauptbeweise bleiben dominant; die vier
  kompakten Portfolio-, Profilaufruf-, X- und E-Mail-Badges sind wieder live.
- Die animierte Contribution Snake ist für Light und Dark Mode live. Stats- und
  Top-Languages-Karten bleiben bewusst draußen.
- Der SHA-gepinnte Drittanbieter-Generator läuft read-only; nur ein separater
  Job mit offiziellen gepinnten Actions veröffentlicht die zwei geparsten,
  passiven SVGs auf `output`.
- Beide GitHub-Actions-Workflows, Live-Darstellung, Pfadbegrenzung,
  Negativfixtures, actionlint, ShellCheck, Gitleaks und unabhängige Reviews sind
  bestätigt; die alten Stats-Dateien auf `output` blieben unverändert.
```

Add a matching short Daily Note entry that links `[[codevena-github-profile]]`
and records the live verification, not merely the local implementation. Inspect
the final vault diff without overwriting or deleting existing content. After
the live checks and both Brain edits are verified, remove only the exact
task-scoped recovery file with
`unlink "$(git rev-parse --git-path codex-visual-snake-recovery.env)"`.
