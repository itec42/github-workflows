# Example: Check a contract against another repository

For two repositories that share no code but agree on a file — for example the example of a release
manifest, which the studio writes and `render` keeps a copy of. The workflow checks the other
repository out beside the calling one and runs one Makefile target of the calling repository.

Workflow: `.github/workflows/reusable-cross-repo-contract-check.yml`

## What it does

1. Checks the calling repository out (depth 2).
2. **Gate:** a pull request from a fork skips everything below (no secrets, and its code does not
   run next to a token). A pull request that changes none of `relevant_paths` also skips it; the job
   stays green, so a required check cannot hang as pending.
3. **Pairing:** checks the other repository out on the branch of the same name as the pull
   request's, otherwise on `main` (`shared/resolve-pair-branch.sh`, ADR-060). A missing branch is a
   notice, not a failure: a merge order that is not finished is shown but does not block.
4. Runs `make <make_target> <make_args>` in the calling repository.

## Usage

```yaml
# .github/workflows/ci.yml of the calling repository
jobs:
  contract-release-manifest:
    name: Contract — release manifest
    if: github.event_name == 'pull_request'
    uses: itec42/github-workflows/.github/workflows/reusable-cross-repo-contract-check.yml@main
    with:
      contract_name: release manifest
      other_repo: itec42/render
      make_target: contract-check-manifest
      make_args: RENDER_DIR=../render
      relevant_paths: |
        app/tests/fixtures/release-manifest.json
        app/tests/fixtures/release-manifest-v2.json
        Makefile
        .github/workflows/ci.yml
    secrets:
      cross_repo_token: ${{ secrets.GH_PAT }}
```

| Input | Required | Purpose |
|-------|----------|---------|
| `contract_name` | yes | Name in the check and the summary |
| `other_repo` | yes | The other repository, `owner/name` |
| `other_repo_dir` | no (`render`) | Folder it is checked out to, beside the calling repository |
| `make_target` | yes | Target of the calling repository that compares the files |
| `make_args` | no | Extra arguments for `make`, split on spaces |
| `relevant_paths` | no | Paths, one per line; empty means always |
| `script_ref` | no (`main`) | Ref the pairing script is read from; see below |

| Secret | Purpose |
|--------|---------|
| `cross_repo_token` | Token that can read the other repository |
| `node_auth_token` | No. `secrets.GITHUB_TOKEN`, for a target that builds the caller's Docker image and installs private `@itec42` packages |

## Rules the workflow keeps

- **No value from the pull request is written into a shell step.** The branch name goes through
  `env:` into the script and into the checkout as its `ref:`. A branch named
  `` `touch x` `` or `x$(touch${IFS}x)` is plain text.
- The workflow sets no `permissions` of its own; it inherits the calling job's. **The caller sets them:**
  `contents: read`, plus `packages: read` when it passes `node_auth_token`. A fixed block in the workflow would
  narrow the token and break the install of private packages.
- The fork skip and the path filter are steps, not `on:` filters.

## Testing a branch of this workflow

Reference the branch and say where the pairing script comes from:

```yaml
    uses: itec42/github-workflows/.github/workflows/reusable-cross-repo-contract-check.yml@my-branch
    with:
      script_ref: my-branch
```

A reusable workflow cannot ask which ref it was called at, so both are set. **Remove both before
the calling repository's pull request is merged** — `@main` and the default `script_ref`.

## Self-test

`bash tests/run-resolve-pair-branch.sh` runs the pairing against a local bare repository, hostile
branch names included. It needs no network and no token.
