# Terraform Deployment Scenarios — github-workflows

**Version**: 1.0.0  
**Last Updated**: 26. März 2026

---

## Overview

Terraform deployment workflow scenarios for infrastructure provisioning.

---

## Scenario 1: Deploy Infrastructure

### Description

Run Terraform init, plan, and apply for service infrastructure.

### User Story

As a DevOps engineer, I want automated Terraform deployments, so that infrastructure changes are consistent.

### Workflow

`reusable-terraform-deploy.yml`

### Inputs

```yaml
terraform_dir: 'terraform'
terraform_version: '1.16.6'
aws_region: 'eu-central-1'
```

### Secrets

```yaml
AWS_ROLE_ARN: 'arn:aws:iam::123456789:role/GitHubActionsRole'
```

### Usage Example

```yaml
# In service repo: .github/workflows/infra.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'

jobs:
  terraform:
    uses: ivodenwag/github-workflows/.github/workflows/reusable-terraform-deploy.yml@v2.0.0
    with:
      terraform_dir: terraform
      terraform_version: '1.16.6'
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

### Flow

1. Checkout code
2. Configure AWS credentials (OIDC)
3. Setup Terraform CLI
4. `terraform init`
5. `terraform validate`
6. `terraform plan -out=tfplan`
7. Upload plan as artifact
8. `terraform apply tfplan`
9. Capture and output terraform outputs

### Outputs

```yaml
terraform_outputs: '{"alb_dns": "xxx.elb.amazonaws.com", "ecs_cluster_arn": "arn:aws:ecs:..."}'
```

### Test Scenarios

#### ✅ Happy Path

- Init succeeds with S3 backend
- Plan shows expected changes
- Apply completes without errors
- Outputs captured for downstream jobs

#### ❌ Error Cases

- **Init fails**: Backend configuration error, S3 access denied
- **Validate fails**: Invalid Terraform syntax
- **Plan fails**: Resource configuration error, missing variables
- **Apply fails**: AWS API error, resource limit reached

### Key Files

- `.github/workflows/reusable-terraform-deploy.yml` — Workflow definition
- `terraform/main.tf` (service repo) — Main configuration
- `terraform/variables.tf` (service repo) — Input variables
- `terraform/outputs.tf` (service repo) — Output definitions
- `terraform/backend.tf` (service repo) — S3 backend config

### Business Rules

- Plan artifact saved for audit trail (30 days retention)
- Apply only from saved plan (no drift)
- OIDC authentication (no static credentials)

---

## Scenario 2: Plan Only (PR Validation)

### Description

Run Terraform plan without apply for PR review.

### User Story

As a reviewer, I want to see infrastructure changes before merge, so that I can validate the impact.

### Usage Pattern

```yaml
name: Terraform Plan

on:
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: eu-central-1
      
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.16.6'
      
      - run: |
          cd terraform
          terraform init
          terraform plan
```

### Test Scenarios

#### ✅ Happy Path

- Plan output visible in PR
- No apply executed

#### ❌ Error Cases

- Plan fails → PR blocked
