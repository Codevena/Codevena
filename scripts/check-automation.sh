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
cleanup() {
  rm -f "$uses_file" "$writes_file" "$generate_file" "$publish_file" \
    "$publish_uses_file" "$generate_permissions_file" \
    "$publish_permissions_file" "$profile_permissions_file"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

grep -R -h -E '^[[:space:]]*uses:' "$workflow_dir" > "$uses_file" \
  || fail "every uses reference must use a full commit SHA"
if grep -Ev '^[[:space:]]*uses:[[:space:]]*[[:alnum:]_.-]+/[[:alnum:]_.\/-]+@[0-9a-f]{40}([[:space:]]+#.*)?$' \
  "$uses_file"; then
  fail "every uses reference must use a full commit SHA"
fi

if grep -R -n -Ei '^[[:space:]]*permissions:[[:space:]]+[^#[:space:]].*$' \
  "$workflow_dir" \
  | grep -Ev 'permissions:[[:space:]]*\{\}[[:space:]]*(#.*)?$'; then
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

extract_job_permissions() {
  job_file="$1"
  destination="$2"
  awk '
    $0 == "    permissions:" { capture = 1 }
    capture && $0 ~ /^    [^ ]/ && $0 != "    permissions:" { exit }
    capture { print }
  ' "$job_file" > "$destination"
}

extract_job generate "$generate_file"
extract_job publish "$publish_file"
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
[[ "$(<"$generate_permissions_file")" == \
   $'    permissions:\n      contents: read' ]] \
  || fail "workflow permissions must match exact allowlist"
[[ "$(<"$publish_permissions_file")" == \
   $'    permissions:\n      contents: write' ]] \
  || fail "workflow permissions must match exact allowlist"

grep -Fq 'uses: Platane/snk@d8f6715049803e982ee5ff501b6b9b7d5deeb09b # v3.5.0' \
  "$generate_file" || fail "Platane/snk must run only in generate"
snake_use_count="$(grep -R -h -F 'uses: Platane/snk@' "$workflow_dir" \
  | wc -l | tr -d ' ')"
[[ "$snake_use_count" -eq 1 ]] \
  || fail "Platane/snk must run only in generate"

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
[[ "$(grep -Fc 'uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1' \
  "$publish_uses_file")" -eq 2 ]] \
  || fail "publish job may only use pinned checkout/download actions"
[[ "$(grep -Fc 'uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c' \
  "$publish_uses_file")" -eq 1 ]] \
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
