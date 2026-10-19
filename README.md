# GitHub Workflows Repository

Centralized, reusable GitHub Actions workflows for all services.

## 🎯 Purpose

This repository contains reusable workflows that standardize CI/CD processes across the organization, including:
- CI testing with Docker Compose
- Semantic versioning with release-it
- Docker image builds and ECR deployment
- Terraform infrastructure deployment
- ECS Blue/Green deployments with CodeDeploy

## 📁 Structure

```
github-workflows/
├── .github/workflows/
│   ├── reusable-ci-docker.yml              # CI testing
│   ├── reusable-release-ecr.yml            # Release + ECR push
│   ├── reusable-terraform-check.yml        # Terraform fmt + validate, on the pull request
│   ├── reusable-terraform-deploy.yml       # Infrastructure deployment
│   ├── reusable-ecs-codedeploy.yml         # ECS Blue/Green via CodeDeploy
│   ├── reusable-ecs-rolling.yml            # ECS rolling update (staging service)
│   └── reusable-service-deployment.yml     # Master orchestration
├── shared/
│   ├── .release-it.json                    # Release-it configuration
│   ├── check-no-plain-http-internal.sh     # CI guard: HTTPS only between services
│   └── terraform-present.sh                # Is there any Terraform here to check?
├── examples/
│   ├── deploy-ecr-with-release.md
│   └── deploy-ecs-with-codedeploy.md       # Full deployment guide
├── README.md
└── CHANGELOG.md
```

## 🚀 Quick Start

### Option 1: Complete Deployment (Recommended)

Use the master orchestration workflow for full deployment pipeline:

```yaml
# .github/workflows/deploy.yml
name: Deploy Service

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    uses: ivodenwag/github-workflows/.github/workflows/reusable-service-deployment.yml@v2.0.0
    with:
      service_name: your-service
      ecr_repository: your-service
      cluster_name: your-cluster
      ecs_service_name: your-ecs-service
      task_family: your-task-family
      container_name: your-container
      codedeploy_application: your-codedeploy-app
      codedeploy_deployment_group: your-deployment-group
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

**See [examples/deploy-ecs-with-codedeploy.md](examples/deploy-ecs-with-codedeploy.md) for complete setup guide.**

### Option 2: Individual Workflows

Use atomic workflows for specific tasks:

```yaml
# CI Testing only
jobs:
  test:
    uses: ivodenwag/github-workflows/.github/workflows/reusable-ci-docker.yml@v2.0.0
    with:
      service_name: your-service

# Release + ECR only
jobs:
  release:
    uses: ivodenwag/github-workflows/.github/workflows/reusable-release-ecr.yml@v2.0.0
    with:
      service_name: your-service
      ecr_repository: your-service
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

## 🔧 Available Workflows

### 1. CI Testing (`reusable-ci-docker.yml`)

Runs tests in Docker Compose environment.

Runs lint, type check, build and tests in a Docker Compose environment.

**Inputs:**
- `compose_files` - Docker compose files (default: `docker-compose.yml docker-compose.ci.yml`)
- `service_name` - Docker compose service name (required)
- `test_target` - Make target for the test step (default: `test`). Use `test-coverage` once the
  service meets its coverage threshold
- `integration_test_target` - Make target for an additional integration step (default: empty →
  step skipped). The caller's compose files have to provide the infrastructure the suite needs,
  and the target itself is responsible for any schema migration

**Jobs:** `Test & Build`, and `No plain HTTP between services` — see below. The second one needs no
inputs and runs for every caller.

**Secrets:**
- `DOCKER_HUB_USERNAME` / `DOCKER_HUB_TOKEN` - optional, avoids Docker Hub rate limits
- `NODE_AUTH_TOKEN` - optional, required to install `@tec42`-scoped packages. Pass
  `secrets.GITHUB_TOKEN` and give the calling workflow `permissions: packages: read`

**Usage:**
```yaml
uses: ivodenwag/github-workflows/.github/workflows/reusable-ci-docker.yml@v2.0.0
with:
  service_name: identity
  test_target: test-coverage
  integration_test_target: test-integration-ci
```

---

### 2. Release & ECR (`reusable-release-ecr.yml`)

Creates semantic version release and pushes Docker image to ECR.

**Inputs:**
- `service_name` - Service name (required)
- `ecr_repository` - ECR repository name (required)
- `compose_files` - Docker compose files
- `aws_region` - AWS region (default: `eu-central-1`)

**Secrets:**
- `AWS_ROLE_ARN` - IAM Role for OIDC (required)
- `NPM_TOKEN` - NPM token (optional)

**Outputs:**
- `version` - Released version (e.g., `v1.2.3`)
- `has_release` - Boolean if release was created

---

### 3. Terraform Deploy (`reusable-terraform-deploy.yml`)

Deploys infrastructure via Terraform.

**Inputs:**
- `terraform_dir` - Path to terraform directory (default: `terraform`)
- `terraform_version` - Terraform version (default: `1.7.0`)
- `aws_region` - AWS region (default: `eu-central-1`)

**Secrets:**
- `AWS_ROLE_ARN` - IAM Role for OIDC (required)
� Prerequisites

### Service Repository Requirements

- **Docker Compose** setup
- **Makefile** with targets: `lint`, `type-check`, `test`, `build`
- **Dockerfile** at `.docker/Dockerfile`
- **Terraform** directory (if using infrastructure deployment)
- **AppSpec** file at `terraform/appspec.yaml` (for ECS deployments)

### AWS Requirements

- ECR Repository
- ECS Cluster + Service (with `deployment_controller.type = CODE_DEPLOY`)
- CodeDeploy Application + Deployment Group
- ALB with 2 Target Groups (Blue + Green)
- IAM Role for GitHub OIDC authentication
- AWS Secrets Manager (for application secrets)

## 🔄 Versioning Strategy

**Production (Recommended):**
```yaml
uses: ivodenwag/github-workflows/.github/workflows/reusable-service-deployment.yml@v2.0.0
```

**Development/Testing:**
```yaml
uses: ivodenwag/github-workflows/.github/workflows/reusable-service-deployment.yml@main
```

**Best Practice:** Pin to specific version tags (`@v2.0.0`) in production to avoid breaking changes.

## 🔐 Security

- **AWS OIDC Authentication**: No static credentials in GitHub Secrets
- **Secrets Manager Integration**: Application secrets stored in AWS
- **Service Ownership**: Each service controls its own appspec.yaml

## 📊 Monitoring & Notifications

**GitHub Email Notifications:**
- Enabled by default in GitHub Settings → Notifications → Actions
- Receive emails on workflow failures

**Optional Slack Integration:**
```yaml
# Add to your workflow
- name: Notify Slack
  if: failure()
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
      -d '{"text":"❌ Deployment failed"}'
```required)
- `container_port` - Container port (default: `3000`)
- `ecr_repository` - ECR repository (required)
- `image_tag` - Docker image tag (required)
- `codedeploy_application` - CodeDeploy app name (required)
- `codedeploy_deployment_group` - Deployment group (required)
- `appspec_path` - Path to appspec.yaml (default: `terraform/appspec.yaml`)
- `aws_region` - AWS region (default: `eu-central-1`)

**Secrets:**
- `AWS_ROLE_ARN` - IAM Role for OIDC (required)

**Outputs:**
- `deployment_id` - CodeDeploy deployment ID
- `task_definition_arn` - New task definition ARN

**Features:**
- Active deployment check (prevents duplicates)
- Task Definition update (preserves secrets)
- Service ownership (loads appspec from service repo)
- Hybrid wait strategy (3 min timeout)
- AWS Console links

---

### 4. ECS Rolling Update (`reusable-ecs-rolling.yml`)

Deploys one ECS service by a rolling update: latest task definition of the family → new image → register →
`update-service` → wait until stable → confirm rollout `COMPLETED` and the new task definition running.

**Inputs:** `cluster_name`, `service_name`, `task_family`, `container_name`, `ecr_repository`, `image_tag`, `aws_region`

**Output:** `task_definition_arn`

### 5. Master Orchestration (`reusable-service-deployment.yml`)

Chains all workflows for complete deployment pipeline.

**Inputs:** 13 inputs covering service, ECS, and CodeDeploy configuration

**Secrets:**
- `AWS_ROLE_ARN` - IAM Role for OIDC (required)
- `NPM_TOKEN` - NPM token (optional)

**Jobs:**
1. `release-ecr` - Create version + push to ECR
2. `deploy-infrastructure` - Terraform (optional, skip with `skip_terraform: true`)
3. `deploy-staging` - Rolling update of a staging service (optional, only when `staging_ecs_service_name` is set), see below
4. `deploy-ecs` - CodeDeploy Blue/Green; starts only when staging succeeded or was skipped

**Optional staging job** (`staging_ecs_service_name`, `staging_task_family`; both empty by default = no staging job, the
service deploys as before): the same image is deployed first to a second ECS service by a rolling update
(`reusable-ecs-rolling.yml`). The job waits until the service is stable **and** confirms that it runs the task definition
this run registered (a rollback by the ECS circuit breaker leaves the service stable on the old version, which fails the
job). A failed staging job stops the pipeline before the CodeDeploy job.

**Features:**
- Conditional execution
- Error handling
- Output passing between jobs

**See:** [examples/deploy-ecs-with-codedeploy.md](examples/deploy-ecs-with-codedeploy.md)

## 🔄 Versioning

Use 2.0.0` - Stable releases
- `v2` - Latest v2.x.x
- `main` - Latest development version

## 🎯 Workflow Features

### CI Workflow
- **Docker Compose based** - Runs in containers with DB/Redis support
- **Make-driven** - All commands via Makefile
- **Automatic version detection** - From Git tags or commit SHA
- **Coverage reports** - Stored as GitHub Artifacts
- **Multi-stage Docker builds** - Optimized caching

### ECR Deployment
- **AWS ECR push** - Automated image deployment
- **Smart tagging** - Version tags + latest for releases
- **Cache optimization** - Faster builds with layer caching
- `main` - Latest development version

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test with a service repository
4. Create a pull request
5. Tag a new version after merge

## 📄 License

MIT

## 🔒 No plain HTTP between services

Services talk HTTPS only (INVEST-005-EPIC-008-FEATURE-001 phase 0, Ralf 2026-09-19). Every caller of
`reusable-ci-docker.yml` gets the job `No plain HTTP between services`, which runs
`shared/check-no-plain-http-internal.sh` over the repository's terraform and workflow files.

**It fails on** an `http://` URL whose host is internal: a `*-internal.tec42.io` name, the raw NLB name
(`*.elb.<region>.amazonaws.com`, `tec42-internal-nlb-*`), or an interpolation that resolves to one of
them (`${local.…_internal_fqdn}`, `$NLB_DNS`).

**It does not fail on** `https://`, a bare port number (step 0.6 still names TCP ports while it runs),
`localhost`, the public ALB's edge hop in front of render, or a line marked with the escape hatch:

```hcl
url = "http://something-internal.tec42.io:3050" # plaintext-ok: <reason it has to stay plain>
```

The fix is the name the NLB listener's certificate covers plus its TLS port, read from remote state
where an output exists:

```hcl
value = "https://${local.vehicle_manager_internal_fqdn}:3052/api/v1"
```

The check is tested against two fixtures under `tests/fixtures/`: one that must pass, and one with four
planted lines that must all be reported. Both assertions live in `tests/run.sh` and in
`.github/workflows/check-no-plain-http-internal.yml`.

> **This repository's GitHub Actions fail at startup for every workflow** — a 12-line workflow that only
> checks the repository out fails the same way, and no run here has ever succeeded. That is a repository
> setting, not a broken file. Until it is fixed, `bash tests/run.sh` is the evidence.

```bash
bash tests/run.sh          # the fixtures
```

Run the check itself against a service with

```bash
bash shared/check-no-plain-http-internal.sh <path to a service checkout>
```
