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
  grep -Fqx "## $heading" "$readme_path" \
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

hero='**[See the production case studies →](https://codevena.dev)**'
hero_count="$(grep -Fxc -- "$hero" "$readme_path" || true)"
[[ "$hero_count" -eq 1 ]] \
  || fail "hero CTA must appear exactly once"

selected_heading='## Selected work'
selected_count="$(grep -Fxc -- "$selected_heading" "$readme_path" || true)"
[[ "$selected_count" -eq 1 ]] \
  || fail "Selected work heading must appear exactly once"

hero_line="$(grep -Fnx -- "$hero" "$readme_path" | cut -d: -f1)"
selected_line="$(grep -Fnx -- "$selected_heading" "$readme_path" | cut -d: -f1)"
[[ "$hero_line" -lt "$selected_line" ]] \
  || fail "hero CTA must appear before Selected work"

url_file="$(mktemp)"
section_file="$(mktemp)"
trap 'rm -f "$url_file" "$section_file"' EXIT
awk -v heading="$selected_heading" '
  $0 == heading { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
' "$readme_path" > "$section_file"

project_row_count="$(grep -Ec '^\| \[\*\*[^]]+\*\*\]\(https://[^)]+\) \|' "$section_file" || true)"
[[ "$project_row_count" -eq 3 ]] \
  || fail "expected exactly 3 project rows in Selected work"

expected_destinations=(
  "https://flashbuddy.app"
  "https://capypad.com"
  "https://github.com/Codevena/reviewgate"
)

for destination in "${expected_destinations[@]}"; do
  destination_count="$(grep -Foc -- "$destination" "$section_file" || true)"
  [[ "$destination_count" -eq 1 ]] \
    || fail "missing selected project destination: $destination"
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
