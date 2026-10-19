# Architecture — github-workflows

**Version**: 1.0.0  
**Last Updated**: 26. März 2026

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    github-workflows Repository                   │
│                    (Central Workflow Library)                    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Atomic Workflows (Building Blocks)            │ │
│  │                                                            │ │
│  │  ┌──────────────────┐  ┌──────────────────────────┐       │ │
│  │  │ CI Testing       │  │ Terraform Deploy         │       │ │
│  │  │ lint, type-check │  │ init, plan, apply        │       │ │
│  │  │ build, test      │  │                          │       │ │
│  │  └──────────────────┘  └──────────────────────────┘       │ │
│  │                                                            │ │
│  │  ┌──────────────────┐  ┌──────────────────────────┐       │ │
│  │  │ Release & ECR    │  │ ECS CodeDeploy           │       │ │
│  │  │ release-it       │  │ task def, appspec        │       │ │
│  │  │ docker, ECR push │  │ blue/green deployment    │       │ │
│  │  └──────────────────┘  └──────────────────────────┘       │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           Orchestration Workflow (Master)                  │ │
│  │                                                            │ │
│  │  reusable-service-deployment.yml                           │ │
│  │  ┌─────────┐ → ┌───────────┐ → ┌─────────────┐            │ │
│  │  │ Release │   │ Terraform │   │ ECS Deploy  │            │ │
│  │  │ + ECR   │   │ (optional)│   │ (CodeDeploy)│            │ │
│  │  └─────────┘   └───────────┘   └─────────────┘            │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ workflow_call
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                     Service Repositories                         │
│                  (identity, render, payment)                     │
│                                                                  │
│  {service}/.github/workflows/deploy.yml                          │
│  - uses: github-workflows/reusable-service-deployment.yml        │
│  - with: { service_name, cluster_name, codedeploy_application }  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Workflow Chaining

### Sequential Execution with `needs`

```yaml
jobs:
  release-ecr:
    uses: ./.github/workflows/reusable-release-ecr.yml
    # Outputs: version
  
  deploy-infra:
    needs: release-ecr           # Waits for release-ecr
    uses: ./.github/workflows/reusable-terraform-deploy.yml
  
  deploy-ecs:
    needs: [release-ecr, deploy-infra]  # Waits for BOTH
    uses: ./.github/workflows/reusable-ecs-codedeploy.yml
    with:
      image_tag: ${{ needs.release-ecr.outputs.version }}
```

---

## Data Flow

```
┌─────────────────────────┐
│ reusable-release-ecr    │
│                         │
│ Outputs:                │
│ - version: "v1.2.3"     │
└──────────┬──────────────┘
           │ needs: release-ecr
           ↓
┌─────────────────────────┐
│ reusable-terraform      │
│                         │
│ Outputs:                │
│ - terraform_outputs     │
└──────────┬──────────────┘
           │ needs: [release-ecr, terraform]
           ↓
┌─────────────────────────┐
│ reusable-ecs-codedeploy │
│                         │
│ Uses:                   │
│ - version: v1.2.3       │
│                         │
│ Creates:                │
│ - Task Definition       │
│ - CodeDeploy deployment │
└─────────────────────────┘
```

---

## Design Patterns

### Pattern 1: Atomic Workflows

Each workflow does ONE thing:

| Workflow | Purpose | Input | Output |
|----------|---------|-------|--------|
| `reusable-ci-docker.yml` | Run tests | `service_name` | pass/fail |
| `reusable-release-ecr.yml` | Release + push | `service_name`, `ecr_repository` | `version` |
| `reusable-terraform-deploy.yml` | Apply terraform | `terraform_dir` | `terraform_outputs` |
| `reusable-ecs-codedeploy.yml` | Deploy to ECS (Blue/Green) | `cluster_name`, `image_tag` | `deployment_id` |
| `reusable-ecs-rolling.yml` | Deploy to ECS (rolling update, staging) | `cluster_name`, `service_name`, `image_tag` | `task_definition_arn` |

### Pattern 2: Orchestration

Master workflow chains atomic workflows:

```yaml
# reusable-service-deployment.yml
jobs:
  release-ecr:
    uses: ./.github/workflows/reusable-release-ecr.yml
    
  deploy-infra:
    needs: release-ecr
    if: ${{ !inputs.skip_terraform }}
    uses: ./.github/workflows/reusable-terraform-deploy.yml
    
  deploy-ecs:
    needs: [release-ecr, deploy-infra]
    uses: ./.github/workflows/reusable-ecs-codedeploy.yml
```

### Pattern 3: Service Ownership

Services provide configuration, workflows provide logic:

```yaml
# Service provides (in service repo):
terraform/appspec.yaml       # Deployment spec
docker-compose.yml           # Build config
Makefile                     # Commands

# Workflow provides (in this repo):
- Standardized steps
- Error handling
- Output passing
```

---

## Deployment Lifecycle

```
Push to main
    ↓
┌─────────────────────────────────┐
│ Job 1: release-ecr              │
│ - Analyze commits               │
│ - Create version (v1.2.3)       │
│ - Build Docker image            │
│ - Push to ECR                   │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│ Job 2: deploy-infra (optional)  │
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
Deployment complete (Blue/Green)
```

---

## Further Documentation

[Overview](01-overview.md) | [Tech Stack](03-tech-stack.md) | [Principles](04-principles.md)
