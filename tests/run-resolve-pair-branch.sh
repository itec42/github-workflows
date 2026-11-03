#!/usr/bin/env bash
#
# tests/run-resolve-pair-branch.sh — the self-test of shared/resolve-pair-branch.sh, runnable anywhere.
#
# The script decides which branch of the other repository a cross-repo check looks at: the branch
# of the same name, otherwise `main`. The branch name comes from a pull request, so it is untrusted
# input — the cases below include names a shell would act on if they were ever expanded.
#
# It uses a local bare repository as the "other repo" (`PAIR_REMOTE_URL`), so it needs no network
# and no token.
#
# Usage: bash tests/run-resolve-pair-branch.sh
set -uo pipefail
cd "$(dirname "$0")/.."

SCRIPT="$PWD/shared/resolve-pair-branch.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ $*"; exit 1; }

# Names a shell would act on: a command separator, a command substitution and backticks. `${IFS}`
# stands in for the space that a git branch name cannot hold.
HOSTILE_SEMICOLON=';touch${IFS}pwned'
HOSTILE_SUBSTITUTION='x$(touch${IFS}pwned)'
HOSTILE_BACKTICKS='`touch${IFS}pwned`'

echo "setup: a bare repository with main, a feature branch and three hostile branch names"
git init -q "$WORK/src" -b main
git -C "$WORK/src" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
for b in feature/paired "$HOSTILE_SEMICOLON" "$HOSTILE_SUBSTITUTION" "$HOSTILE_BACKTICKS"; do
  git -C "$WORK/src" branch "$b" || fail "could not create the branch $b"
done
git clone -q --bare "$WORK/src" "$WORK/other.git"

# run_case <HEAD_REF> — prints the resolved ref; the notice goes to $WORK/notice.
run_case() {
  : > "$WORK/out"
  ( cd "$WORK/run" && \
    HEAD_REF="$1" OTHER_REPO="itec42/other" TOKEN="unused" \
    PAIR_REMOTE_URL="$WORK/other.git" GITHUB_OUTPUT="$WORK/out" \
    bash "$SCRIPT" > "$WORK/notice" 2>&1 )
  local status=$?
  [[ $status -eq 0 ]] || { cat "$WORK/notice"; fail "the script exited with $status for '$1'"; }
  sed -n 's/^ref=//p' "$WORK/out"
}

mkdir "$WORK/run"

echo "1/6 a branch of the same name is used"
got=$(run_case "feature/paired")
[[ "$got" == "feature/paired" ]] || fail "expected feature/paired, got '$got'"
grep -q '::notice::' "$WORK/notice" && fail "a paired branch must not print the fallback notice"

echo "2/6 a missing branch falls back to main and says so"
got=$(run_case "feature/not-there")
[[ "$got" == "main" ]] || fail "expected main, got '$got'"
grep -q '::notice::' "$WORK/notice" || fail "the fallback must print a notice"
grep -q 'feature/not-there' "$WORK/notice" && fail "the notice must not repeat the branch name"

echo "3/6 an empty branch name falls back to main"
got=$(run_case "")
[[ "$got" == "main" ]] || fail "expected main, got '$got'"

echo "4/6 a name that is no valid ref falls back to main"
got=$(run_case "has a space")
[[ "$got" == "main" ]] || fail "expected main, got '$got'"

echo "5/6 hostile branch names are returned as plain text and run nothing"
for b in "$HOSTILE_SEMICOLON" "$HOSTILE_SUBSTITUTION" "$HOSTILE_BACKTICKS"; do
  got=$(run_case "$b")
  [[ "$got" == "$b" ]] || fail "expected the name back unchanged, got '$got' for '$b'"
done
[[ ! -e "$WORK/run/pwned" && ! -e "$PWD/pwned" ]] || fail "a hostile branch name was executed"

echo "6/6 a missing branch name with a hostile value also falls back and runs nothing"
got=$(run_case 'nope$(touch${IFS}pwned)')
[[ "$got" == "main" ]] || fail "expected main, got '$got'"
[[ ! -e "$WORK/run/pwned" && ! -e "$PWD/pwned" ]] || fail "a hostile branch name was executed"

echo
echo "✅ the pairing script behaved as expected in all six cases"
