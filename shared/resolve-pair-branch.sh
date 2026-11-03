#!/usr/bin/env bash
#
# shared/resolve-pair-branch.sh — which branch of the other repository does a cross-repo check read?
#
# The branch of the same name as the pull request's, otherwise `main`. A merge order that is not
# finished yet (the other repo's change is still on its branch, or already merged) therefore reads
# as the right thing and not as a divergence; a missing branch is shown as a notice, never as a
# failure (ADR-060).
#
# The branch name is **untrusted input** — it is chosen by whoever opens the pull request. It is
# read from the environment only, always quoted, never put into a command line, and never repeated
# in the notice (a workflow command is parsed from the log text).
#
# Environment:
#   HEAD_REF          branch name of the pull request (empty → main)
#   OTHER_REPO        `owner/name` of the other repository
#   TOKEN             token that can read OTHER_REPO
#   GITHUB_OUTPUT     file the result is appended to (`ref=<branch>`)
#   PAIR_REMOTE_URL   optional full remote URL; replaces the GitHub URL (used by the self-test)
set -uo pipefail

DEFAULT_BRANCH="main"
HEAD_REF="${HEAD_REF:-}"
OTHER_REPO="${OTHER_REPO:?OTHER_REPO is required}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

if [[ -n "${PAIR_REMOTE_URL:-}" ]]; then
  REMOTE="$PAIR_REMOTE_URL"
else
  # The token stays in this process: git does not log the URL on success, and a failure is
  # silenced below.
  REMOTE="https://x-access-token:${TOKEN:?TOKEN is required}@github.com/${OTHER_REPO}.git"
fi

fall_back() {
  echo "::notice::No branch of the same name in ${OTHER_REPO} — checking out ${DEFAULT_BRANCH}. If a matching change is still unmerged there, the merge order is not finished yet."
  echo "ref=${DEFAULT_BRANCH}" >> "$OUT"
  exit 0
}

[[ -n "$HEAD_REF" ]] || { echo "ref=${DEFAULT_BRANCH}" >> "$OUT"; exit 0; }

# A name git itself would not accept (a space, `..`, a control character) cannot be a branch of the
# other repository, so it is never passed on.
git check-ref-format --branch "$HEAD_REF" > /dev/null 2>&1 || fall_back

if git ls-remote --exit-code --heads "$REMOTE" "refs/heads/${HEAD_REF}" > /dev/null 2>&1; then
  echo "ref=${HEAD_REF}" >> "$OUT"
else
  fall_back
fi
