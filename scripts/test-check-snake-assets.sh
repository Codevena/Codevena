#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
checker="$script_dir/check-snake-assets.py"

if [[ ! -f "$checker" ]]; then
  printf 'snake-assets-test: checker missing: %s\n' "$checker" >&2
  exit 1
fi

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/snake-assets-test.XXXXXX")"

fixture_names=(
  safe missing extra symlink malformed script namespaced-script foreign-object
  event-handler external-reference encoded-scheme css-import relative-css-url
  escaped-css-url external-entity utf16-processing-instruction utf8-bom
)

cleanup() {
  for fixture_name in "${fixture_names[@]}"; do
    fixture_dir="$tmp_root/$fixture_name"
    rm -f "$fixture_dir/github-snake.svg" \
      "$fixture_dir/github-snake-dark.svg" \
      "$fixture_dir/unexpected.svg"
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
  <desc>Animated contribution trail</desc>
  <style>.dot{fill:#40c463;animation:pulse 2s linear infinite;transform:translate(0) scale(1)}@keyframes pulse{50%{opacity:.5}}</style>
  <rect class="dot" x="2" y="2" width="20" height="20" rx="4" ry="4" />
  <rect class="dot" x="28" y="2" width="20" height="20" rx="4" ry="4" />
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
    || {
      printf 'snake-assets-test: wrong rejection for %s\n' "$reason" >&2
      cat "$output" >&2
      exit 1
    }
}

for fixture_name in "${fixture_names[@]}"; do
  write_pair "$tmp_root/$fixture_name"
done

python3 "$checker" "$tmp_root/safe" >"$tmp_root/safe.out" 2>&1
grep -Fqx 'snake-assets: ok (2 passive SVGs)' "$tmp_root/safe.out"

unlink "$tmp_root/missing/github-snake-dark.svg"
printf '%s\n' "$safe_svg" > "$tmp_root/extra/unexpected.svg"

unlink "$tmp_root/symlink/github-snake.svg"
ln -s github-snake-dark.svg "$tmp_root/symlink/github-snake.svg"

printf '%s\n' "${safe_svg%</svg>}" > "$tmp_root/malformed/github-snake.svg"
printf '%s\n' "${safe_svg%</svg>}<script>alert(1)</script></svg>" \
  > "$tmp_root/script/github-snake.svg"
printf '%s\n' "${safe_svg%</svg>}<s:script xmlns:s=\"http://www.w3.org/2000/svg\">alert(1)</s:script></svg>" \
  > "$tmp_root/namespaced-script/github-snake.svg"
printf '%s\n' "${safe_svg%</svg>}<foreignObject>text</foreignObject></svg>" \
  > "$tmp_root/foreign-object/github-snake.svg"
printf '%s\n' "${safe_svg%</svg>}<rect onload=\"alert(1)\" /></svg>" \
  > "$tmp_root/event-handler/github-snake.svg"
printf '%s\n' "${safe_svg%</svg>}<image href=\"https://evil.example/x\" /></svg>" \
  > "$tmp_root/external-reference/github-snake.svg"
printf '%s\n' "${safe_svg%</svg>}<image href=\"jav&#x61;script:alert(1)\" /></svg>" \
  > "$tmp_root/encoded-scheme/github-snake.svg"
printf '%s\n' "${safe_svg%</svg>}<style>@import url(https://evil.example/x.css);</style></svg>" \
  > "$tmp_root/css-import/github-snake.svg"
printf '%s\n' "${safe_svg%</svg>}<style>.x{fill:url(/external.svg)}</style></svg>" \
  > "$tmp_root/relative-css-url/github-snake.svg"
printf '%s\n' "${safe_svg%</svg>}<style>.x{fill:u\\72l(https://evil.example/x)}</style></svg>" \
  > "$tmp_root/escaped-css-url/github-snake.svg"
printf '<!DOCTYPE svg [<!ENTITY x SYSTEM "https://evil.example/entity">]>\n%s\n' \
  "$safe_svg" > "$tmp_root/external-entity/github-snake.svg"

python3 - "$tmp_root/utf16-processing-instruction/github-snake.svg" <<'PY'
import sys
from pathlib import Path

document = '''<?xml-stylesheet href="https://evil.example/x.css"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 24">
  <style>.dot{fill:#40c463}</style>
  <rect class="dot" x="2" y="2" width="20" height="20" rx="4" />
</svg>'''
Path(sys.argv[1]).write_bytes(document.encode("utf-16"))
PY

printf '\357\273\277%s\n' "$safe_svg" \
  > "$tmp_root/utf8-bom/github-snake.svg"

assert_rejected "$tmp_root/missing" missing \
  "expected exactly 2 asset entries"
assert_rejected "$tmp_root/extra" extra \
  "expected exactly 2 asset entries"
assert_rejected "$tmp_root/symlink" symlink \
  "asset must be a regular non-symlink file"
assert_rejected "$tmp_root/malformed" malformed \
  "invalid XML"
assert_rejected "$tmp_root/script" script \
  "active SVG content rejected"
assert_rejected "$tmp_root/namespaced-script" namespaced-script \
  "active SVG content rejected"
assert_rejected "$tmp_root/foreign-object" foreign-object \
  "active SVG content rejected"
assert_rejected "$tmp_root/event-handler" event-handler \
  "active SVG content rejected"
assert_rejected "$tmp_root/external-reference" external-reference \
  "external SVG reference rejected"
assert_rejected "$tmp_root/encoded-scheme" encoded-scheme \
  "external SVG reference rejected"
assert_rejected "$tmp_root/css-import" css-import \
  "external SVG reference rejected"
assert_rejected "$tmp_root/relative-css-url" relative-css-url \
  "external SVG reference rejected"
assert_rejected "$tmp_root/escaped-css-url" escaped-css-url \
  "external SVG reference rejected"
assert_rejected "$tmp_root/external-entity" external-entity \
  "active SVG content rejected"
assert_rejected "$tmp_root/utf16-processing-instruction" \
  utf16-processing-instruction "SVG must be UTF-8 without BOM"
assert_rejected "$tmp_root/utf8-bom" utf8-bom \
  "SVG must be UTF-8 without BOM"

printf 'snake-assets-test: ok (1 safe + 16 rejected fixtures)\n'
