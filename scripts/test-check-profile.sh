#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH='' cd -- "$script_dir/.." && pwd)"
checker="$script_dir/check-profile.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/profile-check-test.XXXXXX")"
missing_cta="$tmp_dir/missing-cta.md"
misplaced_project="$tmp_dir/misplaced-project.md"
extra_project="$tmp_dir/extra-project.md"
unlinked_project="$tmp_dir/unlinked-project.md"

cleanup() {
  rm -f "$missing_cta" "$misplaced_project" "$extra_project" "$unlinked_project" \
    "$tmp_dir/missing-cta.out" "$tmp_dir/misplaced-project.out" \
    "$tmp_dir/extra-project.out" "$tmp_dir/unlinked-project.out"
  if [ -d "$tmp_dir" ]; then
    rmdir "$tmp_dir"
  fi
}
trap cleanup EXIT HUP INT TERM

assert_rejected() {
  fixture="$1"
  reason="$2"
  expected="$3"
  output="$tmp_dir/${reason}.out"

  if CHECK_PROFILE_SKIP_NETWORK=1 bash "$checker" "$fixture" >"$output" 2>&1; then
    printf 'profile-test: expected rejection for %s\n' "$reason" >&2
    exit 1
  fi

  grep -Fqx "profile-check: $expected" "$output" \
    || {
      printf 'profile-test: wrong rejection for %s\n' "$reason" >&2
      cat "$output" >&2
      exit 1
    }
}

awk '$0 != "**[See the production case studies →](https://codevena.dev)**"' \
  "$repo_dir/README.md" >"$missing_cta"

awk '
  /^\|.*ReviewGate/ {
    print "| [**Displaced**](https://displaced.example) | Outside-proof fixture. | Test proof |"
    next
  }
  /## More shipped/ {
    print
    print "- [**ReviewGate**](https://github.com/Codevena/reviewgate) — moved outside the selected proof set."
    next
  }
  { print }
' "$repo_dir/README.md" >"$misplaced_project"

awk '
  /## Selected work/ { print; in_selected = 1; next }
  in_selected && /^\|---\|---\|---\|$/ {
    print
    print "| Fourth project | Extra proof | Extra claim |"
    next
  }
  in_selected && /^## / { in_selected = 0 }
  { print }
' "$repo_dir/README.md" >"$extra_project"

awk '
  {
    token = "[**Flashbuddy**](https://flashbuddy.app)"
    start = index($0, token)
    if (start > 0) {
      line = substr($0, 1, start - 1) "**Flashbuddy**" substr($0, start + length(token))
      needle = " | FSRS scheduling"
      proof = index(line, needle)
      line = substr(line, 1, proof - 1) " | https://flashbuddy.app · FSRS scheduling" substr(line, proof + length(needle))
      print line
      next
    }
  }
  { print }
' "$repo_dir/README.md" >"$unlinked_project"

assert_rejected "$missing_cta" missing-cta "hero CTA must appear exactly once"
assert_rejected "$misplaced_project" misplaced-project "missing selected project link pair: [**ReviewGate**](https://github.com/Codevena/reviewgate)"
assert_rejected "$extra_project" extra-project "expected exactly 3 project rows in Selected work"
assert_rejected "$unlinked_project" unlinked-project "missing selected project link pair: [**Flashbuddy**](https://flashbuddy.app)"

printf 'profile-test: ok (4 negative fixtures rejected)\n'
