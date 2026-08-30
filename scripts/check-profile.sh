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
  "Contribution trail"
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
hero_section_file="$(mktemp)"
snake_section_file="$(mktemp)"
trap 'rm -f "$url_file" "$section_file" "$hero_section_file" "$snake_section_file"' EXIT

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

awk -v heading="$selected_heading" '
  $0 == heading { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
' "$readme_path" > "$section_file"

project_row_count="$(awk '
  /^\|/ {
    if ($0 == "| Work | What shipped | Proof |" ||
        $0 == "|---|---|---|") {
      next
    }
    count++
  }
  END { print count + 0 }
' "$section_file")"
[[ "$project_row_count" -eq 3 ]] \
  || fail "expected exactly 3 project rows in Selected work"

expected_project_links=(
  "[**Flashbuddy**](https://flashbuddy.app)"
  "[**Capypad**](https://capypad.com)"
  "[**ReviewGate**](https://github.com/Codevena/reviewgate)"
)

for project_link in "${expected_project_links[@]}"; do
  project_link_count="$(grep -Foc -- "$project_link" "$section_file" || true)"
  [[ "$project_link_count" -eq 1 ]] \
    || fail "missing selected project link pair: $project_link"
done

contribution_heading='## Contribution trail'
more_shipped_heading='## More shipped'
contribution_count="$(grep -Fxc -- "$contribution_heading" "$readme_path" || true)"
[[ "$contribution_count" -eq 1 ]] \
  || fail "Contribution trail heading must appear exactly once"

contribution_line="$(grep -Fnx -- "$contribution_heading" "$readme_path" | cut -d: -f1)"
more_shipped_line="$(grep -Fnx -- "$more_shipped_heading" "$readme_path" | cut -d: -f1)"
[[ "$selected_line" -lt "$contribution_line" && \
   "$contribution_line" -lt "$more_shipped_line" ]] \
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
[[ "$light_count" -eq 2 ]] \
  || fail "missing contribution snake URL: $light_snake"
[[ "$dark_count" -eq 1 ]] \
  || fail "missing contribution snake URL: $dark_snake"
grep -Fq "alt=\"Animated contribution snake for Codevena's GitHub activity\"" \
  "$snake_section_file" \
  || fail "missing approved contribution snake alt text"

banned_terms=(
  "stats.svg"
  "top-langs.svg"
  "assets/banner.jpg"
)

for term in "${banned_terms[@]}"; do
  if grep -Fq -- "$term" "$readme_path"; then
    fail "banned retired asset reference: $term"
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
