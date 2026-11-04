# Project Structure — github-workflows

**Version**: 1.0.0  
**Last Updated**: 26. März 2026

---

## Directory Overview

```
github-workflows/
├── .github/
│   └── workflows/
│       ├── reusable-ci-docker.yml           # CI testing
│       ├── reusable-release-ecr.yml         # Release + ECR push
│       ├── reusable-terraform-deploy.yml    # Terraform apply
│       ├── reusable-ecs-codedeploy.yml      # ECS Blue/Green
│       └── reusable-service-deployment.yml  # Master orchestration
├── shared/
│   └── .release-it.json                     # Release-it config
├── examples/
│   ├── deploy-ecr-with-release.md           # ECR deployment guide
│   └── deploy-ecs-with-codedeploy.md        # Full deployment guide
├── .ai/
│   ├── context/                             # Documentation
│   ├── scenarios/                           # Usage scenarios
│   └── workflows/                           # Development guides
├── README.md
└── CHANGELOG.md
```

---

## Key Directories

### `.github/workflows/`

Reusable workflow definitions.

| File | Purpose | Inputs | Outputs |
|------|---------|--------|---------|
| `reusable-ci-docker.yml` | Run tests in Docker | `service_name`, `compose_files` | — |
| `reusable-release-ecr.yml` | Create release, push to ECR | `service_name`, `ecr_repository` | `version` |
| `reusable-terraform-deploy.yml` | Apply Terraform | `terraform_dir` | `terraform_outputs` |
| `reusable-ecs-codedeploy.yml` | Deploy to ECS | `cluster_name`, `image_tag`, ... | `deployment_id` |
| `reusable-service-deployment.yml` | Chain all workflows | 13 inputs | — |
| `reusable-cross-repo-contract-check.yml` | Check a contract file against another repo on the branch of the same name, else `main` | `contract_name`, `other_repo`, `make_target`, ... | — |

### `shared/`

Shared configuration files downloaded by workflows.

| File | Purpose |
|------|---------|
| `.release-it.json` | Semantic versioning config |
| `resolve-pair-branch.sh` | Branch of the other repo to check out: same name, else `main` (self-test: `tests/run-resolve-pair-branch.sh`) |

### `examples/`

Usage documentation for service teams.

| File | Purpose |
|------|---------|
| `deploy-ecr-with-release.md` | How to deploy to ECR |
| `deploy-ecs-with-codedeploy.md` | Complete deployment guide |
| `cross-repo-contract-check.md` | Check a contract against another repository |

---

## Key Files

### Workflow Files

#### `reusable-ci-docker.yml`

```yaml
on:
  workflow_call:
    inputs:
      service_name: { required: true }
      compose_files: { default: 'docker-compose.yml docker-compose.ci.yml' }

jobs:
  test:
    steps:
      - Checkout
      - Create dummy secrets
      - Build Docker images
      - Lint (make lint)
      - Type check (make type-check)
      - Build (make build)
      - Test (make test)
```

#### `reusable-release-ecr.yml`

```yaml
on:
  workflow_call:
    inputs:
      service_name: { required: true }
      ecr_repository: { required: true }
    secrets:
      AWS_ROLE_ARN: { required: true }
    outputs:
      version: { value: ${{ jobs.deploy.outputs.version }} }

jobs:
  test: { ... }      # Run tests
  release: { ... }   # Create version via release-it
  deploy: { ... }    # Push to ECR
```

#### `reusable-service-deployment.yml`

```yaml
on:
  workflow_call:
    inputs:
      service_name, ecr_repository         # Identity
      cluster_name, ecs_service_name, ...  # ECS
      codedeploy_application, ...          # CodeDeploy
      skip_terraform                       # Options

jobs:
  release-ecr:    → reusable-release-ecr.yml
  deploy-infra:   → reusable-terraform-deploy.yml (if !skip_terraform)
  deploy-ecs:     → reusable-ecs-codedeploy.yml
```

### Configuration Files

#### `shared/.release-it.json`

```json
{
  "git": {
    "commitMessage": "chore: release ${version}",
    "tagName": "${version}",
    "requireBranch": "main"
  },
  "github": { "release": true },
  "increment": "conventional",
  "npm": { "publish": false },
  "plugins": {
    "@release-it/conventional-changelog": {
      "preset": { "name": "conventionalcommits" }
    }
  }
}
```

---

## Naming Conventions

### Workflow Files

```
reusable-{scope}-{action}.yml
```

| Pattern | Examples |
|---------|----------|
| `reusable-ci-*` | `reusable-ci-docker.yml` |
| `reusable-*-ecr` | `reusable-release-ecr.yml`, `reusable-deploy-ecr.yml` |
| `reusable-*-deploy` | `reusable-terraform-deploy.yml` |
| `reusable-ecs-*` | `reusable-ecs-codedeploy.yml` |

### Input Naming

```yaml
# Use snake_case for inputs
service_name: { ... }
ecr_repository: { ... }
aws_region: { ... }
```

### Output Naming

```yaml
# Use snake_case for outputs
outputs:
  version: { ... }
  deployment_id: { ... }
  task_definition_arn: { ... }
```

---

## Further Documentation

[Overview](01-overview.md) | [Architecture](02-architecture.md) | [Development](07-development.md)
