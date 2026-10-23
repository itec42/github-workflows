# Example: Publish an npm Package to GitHub Packages

For repositories whose artifact is a package rather than a Docker image — `lib-acl` is the first.
The Docker-image counterpart is [deploy-ecr-with-release.md](deploy-ecr-with-release.md).

## Prerequisites

### 0. Package access for consuming repositories

This one bites the *consumer*, not the publisher, and it is worth knowing before you publish
anything private.

A private package is linked to the repository that published it, and GitHub Packages grants read
access **per package and repository** — separately from repository permissions. Another service's
`GITHUB_TOKEN` may carry `packages: read` and still be refused: that permission lets it read
packages it is entitled to, and entitlement is granted on the package.

An org owner adds each consumer once:

**github.com/orgs/{org}/packages/npm/package/{name}** → *Package settings* →
**Manage Actions access** → *Add repository* → role **Read**

It is on the **package page**, not in the publishing repository's settings — there is no entry for
it under Settings → Access.

The symptom is a **403, not a 401**:

```
npm error 403 Forbidden - GET https://npm.pkg.github.com/download/@scope/name/1.0.0/…
npm error 403 Permission permission_denied: read_package
```

A 401 means the token never arrived; a 403 means it arrived and is valid. It only appears in CI —
a personal access token has org-wide reach, so local installs work right up to the first pipeline
run. Setting the package to **internal** visibility instead makes every repository in the org a
permitted reader, at the cost of the per-consumer decision.

### 1. Secrets

- `GITHUB_TOKEN` — provided automatically; no setup needed
- `DOCKER_HUB_USERNAME` / `DOCKER_HUB_TOKEN` — optional, only to avoid Docker Hub rate limits

No AWS role and no OIDC: nothing here talks to AWS.

### 2. Package configuration

`package.json` must point at GitHub Packages and declare what ships:

```json
{
  "name": "@tec42/your-package",
  "publishConfig": { "registry": "https://npm.pkg.github.com" },
  "files": ["dist"]
}
```

`.npmrc` maps the scope for consumers:

```
@tec42:registry=https://npm.pkg.github.com
```

### 3. Compose files

The workflow needs **two** sets, and the difference matters:

| Input | Used for | Requirement |
|---|---|---|
| `compose_files` | the test job | the usual CI pair, `volumes: []` is fine |
| `build_compose_files` | the publish job | **must bind-mount the workspace** |

`docker-compose.ci.yml` sets `volumes: []`, so a build under it writes `dist/` inside a container
that is then thrown away. Publishing from that state uploads a package with no code — and since
GitHub Packages does not allow republishing a version, the number is spent for good. The publish
job therefore builds under the override file and refuses to publish if `dist_entry` is missing.

### 4. Workflow file

`.github/workflows/release.yml`:

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Run without publishing'
        type: boolean
        default: false

# Do not omit this block. See the warning below.
permissions:
  contents: write
  packages: write

jobs:
  release:
    uses: itec42/github-workflows/.github/workflows/reusable-npm-publish.yml@main
    with:
      service_name: your-package
      dry_run: ${{ inputs.dry_run }}
    secrets:
      DOCKER_HUB_USERNAME: ${{ secrets.DOCKER_HUB_USERNAME }}
      DOCKER_HUB_TOKEN: ${{ secrets.DOCKER_HUB_TOKEN }}
```

> ⚠️ **The `permissions` block belongs on the caller**, even though the reusable workflow declares
> the same one. A called workflow can never hold more than the caller grants it, and tec42
> repositories default to a read-only workflow token
> (Settings → Actions → Workflow permissions). Without it the run ends in `startup_failure`
> **before any job starts** — there is no log to read and no failed step to point at, which makes
> it a genuinely confusing few minutes. `identity` and `render` declare permissions on the caller
> for the same reason.
>
> The alternative — switching the repository default to read-write — works too, but grants every
> workflow in the repository more than it needs.

Trigger on `workflow_dispatch` while a package is young: publishing stays a deliberate act and a
version cannot be spent by accident. Switch to `push: branches: [main]` once the API is settled.

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `service_name` | Yes | — | Docker compose service name |
| `compose_files` | No | `docker-compose.yml docker-compose.ci.yml` | Test job compose files |
| `build_compose_files` | No | `docker-compose.yml docker-compose.override.yml` | Publish job compose files — must bind-mount |
| `dist_entry` | No | `dist/src/index.js` | Guard file that must exist after the build |
| `node_version` | No | `22` | Node.js for release-it and npm publish |
| `pre_release` | No | `''` | Prerelease identifier, e.g. `rc` |
| `dry_run` | No | `false` | Run everything without releasing or publishing |

## Outputs

| Output | Description |
|---|---|
| `version` | The version that was released |
| `has_release` | `false` when the commits produced no version bump, or on a dry run |

## How it works

1. **Test** — lint, type-check, build, test, the same sequence as `reusable-ci-docker.yml`
2. **Release** — `release-it --ci --no-npm` with the shared `shared/.release-it.json`; the version
   is derived from conventional commits, and `CHANGELOG.md`, the git tag and the GitHub Release
   are created
3. **Publish** — checks out the new tag, rebuilds with the workspace mounted, verifies the build
   output actually reached the runner, then `npm publish`

Versioning is deliberately split from publishing, exactly as `reusable-release-ecr.yml` splits it
from the ECR push. One shared release-it config governs every tec42 repository; a second variant
would drift.

## Testing a change to this workflow

Never test against `main`. Reference the branch from a consuming repository and use a prerelease:

```yaml
jobs:
  release:
    uses: itec42/github-workflows/.github/workflows/reusable-npm-publish.yml@feature/your-branch
    with:
      service_name: your-package
      pre_release: rc
      dry_run: true
```

Start with `dry_run: true` — it exercises release-it, the build, the guard and `npm publish
--dry-run` without creating a tag or consuming a version. Then repeat with `dry_run: false` and
`pre_release: rc` for a real but disposable `x.y.z-rc.N`, and only merge afterwards.
