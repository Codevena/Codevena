#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH='' cd -- "$script_dir/.." && pwd)"
checker="$script_dir/check-automation.sh"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/automation-test.XXXXXX")"

fixture_names=(
  mutable-ref extra-write write-all inline-write generate-other-write
  quoted-generate-write generator-in-publish force-push
)

cleanup() {
  for fixture_name in "${fixture_names[@]}"; do
    fixture_dir="$tmp_root/$fixture_name"
    rm -f "$fixture_dir/.github/workflows/profile-check.yml" \
      "$fixture_dir/.github/workflows/contribution-snake.yml" \
      "$fixture_dir/.github/workflows/profile-check.yml.tmp" \
      "$fixture_dir/.github/workflows/contribution-snake.yml.tmp"
    if [[ -d "$fixture_dir/.github/workflows" ]]; then
      rmdir "$fixture_dir/.github/workflows"
    fi
    if [[ -d "$fixture_dir/.github" ]]; then
      rmdir "$fixture_dir/.github"
    fi
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

  if /bin/bash "$checker" "$fixture_dir/.github/workflows" \
    >"$output" 2>&1; then
    printf 'automation-test: expected rejection for %s\n' "$reason" >&2
    exit 1
  fi

  grep -Fq "automation-check: $expected" "$output" \
    || {
      printf 'automation-test: wrong rejection for %s\n' "$reason" >&2
      cat "$output" >&2
      exit 1
    }
}

/bin/bash "$checker" >"$tmp_root/baseline.out" 2>&1
grep -Fqx 'automation-check: ok' "$tmp_root/baseline.out"

mutable_dir="$tmp_root/mutable-ref"
seed_fixture "$mutable_dir"
awk '{ gsub("3d3c42e5aac5ba805825da76410c181273ba90b1", "v7"); print }' \
  "$mutable_dir/.github/workflows/profile-check.yml" \
  > "$mutable_dir/.github/workflows/profile-check.yml.tmp"
mv "$mutable_dir/.github/workflows/profile-check.yml.tmp" \
  "$mutable_dir/.github/workflows/profile-check.yml"

extra_write_dir="$tmp_root/extra-write"
seed_fixture "$extra_write_dir"
printf '\nfixture:\n  permissions:\n    contents: write\n' \
  >> "$extra_write_dir/.github/workflows/profile-check.yml"

write_all_dir="$tmp_root/write-all"
seed_fixture "$write_all_dir"
awk '{ sub(/^permissions: \{\}$/, "permissions: write-all"); print }' \
  "$write_all_dir/.github/workflows/contribution-snake.yml" \
  > "$write_all_dir/.github/workflows/contribution-snake.yml.tmp"
mv "$write_all_dir/.github/workflows/contribution-snake.yml.tmp" \
  "$write_all_dir/.github/workflows/contribution-snake.yml"

inline_write_dir="$tmp_root/inline-write"
seed_fixture "$inline_write_dir"
awk '{ sub(/^permissions: \{\}$/, "permissions: {contents: write}"); print }' \
  "$inline_write_dir/.github/workflows/contribution-snake.yml" \
  > "$inline_write_dir/.github/workflows/contribution-snake.yml.tmp"
mv "$inline_write_dir/.github/workflows/contribution-snake.yml.tmp" \
  "$inline_write_dir/.github/workflows/contribution-snake.yml"

generator_write_dir="$tmp_root/generate-other-write"
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

quoted_write_dir="$tmp_root/quoted-generate-write"
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

publish_dir="$tmp_root/generator-in-publish"
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

force_dir="$tmp_root/force-push"
seed_fixture "$force_dir"
awk '{ gsub("git push origin HEAD:output", "git push --force origin HEAD:output"); print }' \
  "$force_dir/.github/workflows/contribution-snake.yml" \
  > "$force_dir/.github/workflows/contribution-snake.yml.tmp"
mv "$force_dir/.github/workflows/contribution-snake.yml.tmp" \
  "$force_dir/.github/workflows/contribution-snake.yml"

assert_rejected "$mutable_dir" mutable-ref \
  "every uses reference must use a full commit SHA"
assert_rejected "$extra_write_dir" extra-write \
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
