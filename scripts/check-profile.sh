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
