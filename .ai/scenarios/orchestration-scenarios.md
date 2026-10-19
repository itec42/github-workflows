# Orchestration Scenarios — github-workflows

**Version**: 1.0.0  
**Last Updated**: 26. März 2026

---

## Overview

Master orchestration workflow scenarios for complete service deployment pipelines.

---

## Scenario 1: Full Service Deployment

### Description

Complete deployment pipeline: test → release → ECR push → Terraform → ECS CodeDeploy.

### User Story

As a developer, I want one workflow for complete deployment, so that I don't have to chain multiple workflows manually.

### Workflow

`reusable-service-deployment.yml`

### Inputs

```yaml
# Service Identity
service_name: 'identity'
ecr_repository: 'identity'

# ECS Configuration
cluster_name: 'tec42-cluster'
ecs_service_name: 'tec42-identity-service'
task_family: 'tec42-identity-task'
container_name: 'identity'
container_port: 3010

# CodeDeploy Configuration
codedeploy_application: 'tec42-identity-app'
codedeploy_deployment_group: 'tec42-identity-dg'

# Options
skip_terraform: false
```

### Secrets

```yaml
AWS_ROLE_ARN: 'arn:aws:iam::123456789:role/GitHubActionsRole'
```

### Usage Example

```yaml
# In service repo: .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: ivodenwag/github-workflows/.github/workflows/reusable-service-deployment.yml@v2.0.0
    with:
      service_name: identity
      ecr_repository: identity
      cluster_name: tec42-cluster
      ecs_service_name: tec42-identity-service
      task_family: tec42-identity-task
      container_name: identity
      container_port: 3010
      codedeploy_application: tec42-identity-app
      codedeploy_deployment_group: tec42-identity-dg
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

### Flow

```
Push to main
    ↓
┌─────────────────────────────────┐
│ Job 1: release-ecr              │
│ - Test (lint, type-check, test) │
│ - Create release (v1.2.3)       │
│ - Push to ECR                   │
│ Output: version                 │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│ Job 2: deploy-infra             │
│ - terraform init                │
│ - terraform plan                │
│ - terraform apply               │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│ Job 3: deploy-ecs               │
│ - Update Task Definition        │
│ - Create AppSpec                │
│ - Start CodeDeploy              │
│ - Wait for deployment           │
└─────────────────────────────────┘
    ↓
Deployment complete
```

### Test Scenarios

#### ✅ Happy Path

- All three jobs complete successfully
- Version output passed between jobs
- Blue/Green deployment completes

#### ❌ Error Cases

- **Tests fail** (Job 1): Pipeline stops, no release created
- **Terraform fails** (Job 2): ECS deployment skipped
- **CodeDeploy fails** (Job 3): Application rolls back

### Key Files

- `.github/workflows/reusable-service-deployment.yml` — Master workflow
- Service repo files:
  - `docker-compose.yml` — Build config
  - `terraform/` — Infrastructure
  - `terraform/appspec.yaml` — Deployment spec
  - `Makefile` — Test commands

---

## Scenario 2: Deployment Without Terraform

### Description

Deploy service without infrastructure changes (frontend services, stateless services).

### User Story

As a frontend developer, I want to skip Terraform, so that deployment is faster when I have no infrastructure.

### Inputs

```yaml
service_name: 'render'
ecr_repository: 'render'
cluster_name: 'tec42-cluster'
ecs_service_name: 'tec42-render-service'
task_family: 'tec42-render-task'
container_name: 'render'
container_port: 3000
codedeploy_application: 'tec42-render-app'
codedeploy_deployment_group: 'tec42-render-dg'
skip_terraform: true  # ← Skip infrastructure
```

### Flow

```
Push to main
    ↓
┌─────────────────────────────────┐
│ Job 1: release-ecr              │
│ - Test, Release, Push to ECR    │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│ Job 2: deploy-infra             │
│ - SKIPPED (skip_terraform=true) │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│ Job 3: deploy-ecs               │
│ - CodeDeploy deployment         │
└─────────────────────────────────┘
```

### Test Scenarios

#### ✅ Happy Path

- Terraform job skipped
- Direct transition from release to ECS deploy
- Faster overall deployment

#### ❌ Error Cases

- Missing infrastructure causes ECS deployment to fail

---

## Scenario 3: Conditional Deployment

### Description

Only deploy when release is created (no deployment for non-conventional commits).

### User Story

As a team, I want deployments only when there's a version bump, so that routine commits don't trigger deployments.

### Behavior

```yaml
# In reusable-service-deployment.yml
deploy-ecs:
  needs: [release-ecr, deploy-infra]
  if: always() && needs.release-ecr.outputs.has_release == 'true'
```

### Flow

```
Push with "chore: update readme"
    ↓
┌─────────────────────────────────┐
│ Job 1: release-ecr              │
│ - No conventional commit        │
│ - has_release: false            │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│ Job 2, 3: SKIPPED               │
│ - Condition not met             │
└─────────────────────────────────┘
```

### Test Scenarios

#### ✅ Expected Behavior

- Commit without `feat:`/`fix:` → No deployment
- Commit with `feat:` → Full deployment

---

## Scenario 4: Staging Service Before Production (INVEST-005/EPIC-007/FEATURE-002/US-004)

### Description

A service with a second ECS service for staging deploys that service by a rolling update first and the production
service by CodeDeploy only after staging succeeded.

### User Story

As a developer, I want the pipeline to deploy the same image first to staging and then to production, so that a change is
tried on staging before customers see it.

### Inputs

```yaml
staging_ecs_service_name: 'render-staging'   # empty (default) = no staging job
staging_task_family: 'render-staging'
```

### Flow

```
release-ecr → deploy-infrastructure → (bootstrap, seed) → deploy-staging → deploy-ecs
                                                              │ fails
                                                              └──→ deploy-ecs is skipped
```

### Behavior (truth table for `deploy-ecs`)

| `staging_ecs_service_name` | `deploy-staging` | `deploy-ecs` |
|---|---|---|
| empty | skipped | runs as before (the other conditions unchanged) |
| set | success | runs |
| set | failure | skipped |
| set | skipped because an earlier job failed | skipped (the earlier failure already blocks it) |

### Test Scenarios

#### ✅ Expected Behavior

- Inputs empty → pipeline identical to before
- Staging confirmed → production deployed with the same image tag

#### ❌ Error Cases

- Staging not stable in about 10 minutes → job fails, production skipped
- Staging rolled back by the circuit breaker (stable on the old task definition) → job fails, production skipped
