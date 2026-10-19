# ECS Deployment with CodeDeploy Blue/Green

Complete guide for deploying services to ECS using CodeDeploy Blue/Green strategy.

---

## 🎯 Overview

The master orchestration workflow (`reusable-service-deployment.yml`) chains three workflows:

```
1. Release & ECR Push  →  2. Terraform (optional)  →  3. CodeDeploy Blue/Green
```

**Result**: Zero-downtime deployments with automatic rollback on failure.

---

## 📋 Prerequisites

### 1. AWS Infrastructure (via tf-aws-infra)

- ✅ VPC with subnets
- ✅ ALB with 2 Target Groups (Blue + Green)
- ✅ ECS Cluster
- ✅ ECS Service with `deployment_controller.type = CODE_DEPLOY`
- ✅ CodeDeploy Application + Deployment Group
- ✅ ECR Repository
- ✅ IAM Roles (ECS Task, ECS Execution, CodeDeploy)

### 2. Service Repository Requirements

- ✅ Docker Compose setup
- ✅ Terraform directory with infrastructure code
- ✅ **AppSpec file**: `terraform/appspec.yaml`
- ✅ GitHub Secrets: `AWS_ROLE_ARN`

---

## 🏗️ Service Repository Setup

### Step 1: Create AppSpec File

Each service must provide its own `terraform/appspec.yaml`:

```yaml
# identity/terraform/appspec.yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "identity"
          ContainerPort: 3010
        PlatformVersion: "LATEST"
```

```yaml
# render/terraform/appspec.yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "render"
          ContainerPort: 3000
        PlatformVersion: "LATEST"
```

**Note**: `<TASK_DEFINITION>` is a placeholder - the workflow replaces it with the actual ARN.

---

### Step 2: Create Deployment Workflow

Create `.github/workflows/deploy.yml` in your service repository:

#### Example 1: Identity Service (with Terraform)

```yaml
# identity/.github/workflows/deploy.yml
name: Deploy Identity Service

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    uses: ivodenwag/github-workflows/.github/workflows/reusable-service-deployment.yml@v2.0.0
    with:
      # Service Identity
      service_name: identity
      ecr_repository: identity
      
      # ECS Configuration
      cluster_name: tec42-cluster
      ecs_service_name: tec42-identity-service
      task_family: tec42-identity-task
      container_name: identity
      container_port: 3010
      
      # CodeDeploy Configuration
      codedeploy_application: tec42-identity-app
      codedeploy_deployment_group: tec42-identity-dg
      
      # Options
      skip_terraform: false  # Deploy infrastructure (has RDS, Redis)
      
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

#### Example 2: Render Service (without Terraform)

```yaml
# render/.github/workflows/deploy.yml
name: Deploy Render Service

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    uses: ivodenwag/github-workflows/.github/workflows/reusable-service-deployment.yml@v2.0.0
    with:
      # Service Identity
      service_name: render
      ecr_repository: render
      
      # ECS Configuration
      cluster_name: tec42-cluster
      ecs_service_name: tec42-render-service
      task_family: tec42-render-task
      container_name: render
      container_port: 3000
      
      # CodeDeploy Configuration
      codedeploy_application: tec42-render-app
      codedeploy_deployment_group: tec42-render-dg
      
      # Options
      skip_terraform: true  # No infrastructure (frontend only)
      
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

---

### Step 3: Configure GitHub Secrets

In your service repository settings:

```
Settings → Secrets and variables → Actions → New repository secret
```

Add:
- **Name**: `AWS_ROLE_ARN`
- **Value**: `arn:aws:iam::123456789012:role/GitHubActionsRole`

**Note**: This role is created by tf-aws-infra and has OIDC trust relationship with GitHub.

---

## 🔄 Deployment Flow

### Timeline

```
0:00  Push to main
      ↓
0:01  Job 1: release-ecr
      ├─ Run tests
      ├─ Create version (release-it)
      ├─ Build Docker image
      └─ Push to ECR
      
0:05  Job 2: deploy-infrastructure (if not skipped)
      ├─ Terraform init
      ├─ Terraform plan (artifact uploaded)
      └─ Terraform apply
      
0:15  Job 3: deploy-ecs
      ├─ Check active deployments
      ├─ Download Task Definition
      ├─ Update image tag
      ├─ Register new revision
      ├─ Load appspec.yaml
      ├─ Create CodeDeploy deployment
      └─ Wait for initial health check (3 min)
      
0:25  Deployment completes in background
      ├─ Traffic shift: 10% per minute
      ├─ Health checks after each shift
      └─ Full traffic to new version
      
0:30  ✅ Deployment complete
```

---

## 🔐 Secret Management

### Development (Docker Compose)

```
identity/
├── secrets/                    # Gitignored
│   ├── database_password.txt
│   └── jwt_secret.txt
└── docker-compose.yml
```

### Production (AWS Secrets Manager)

Secrets are managed via Terraform:

```hcl
# identity/terraform/secrets.tf
resource "aws_secretsmanager_secret" "db_password" {
  name = "tec42/identity/database_password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.database_password
}
```

Task Definition references them:

```hcl
# identity/terraform/ecs-task-definition.tf
resource "aws_ecs_task_definition" "identity" {
  family = "tec42-identity-task"
  
  container_definitions = jsonencode([{
    name  = "identity"
    image = "${aws_ecr_repository.identity.repository_url}:latest"
    
    secrets = [
      {
        name      = "DATABASE_PASSWORD"
        valueFrom = aws_secretsmanager_secret.db_password.arn
      }
    ]
  }])
  
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
}
```

**The workflow preserves all secrets** when updating the Task Definition - it only changes the image tag.

---

## 🎯 Workflow Inputs Reference

### Required Inputs

| Input | Description | Example |
|-------|-------------|---------|
| `service_name` | Service identifier | `identity` |
| `ecr_repository` | ECR repo name | `identity` |
| `cluster_name` | ECS cluster | `tec42-cluster` |
| `ecs_service_name` | ECS service | `tec42-identity-service` |
| `task_family` | Task definition family | `tec42-identity-task` |
| `codedeploy_application` | CodeDeploy app | `tec42-identity-app` |
| `codedeploy_deployment_group` | Deployment group | `tec42-identity-dg` |

### Optional Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `container_name` | Container name | `app` |
| `container_port` | Container port | `3000` |
| `skip_terraform` | Skip infrastructure | `false` |
| `terraform_dir` | Terraform directory | `terraform` |
| `appspec_path` | Path to appspec.yaml | `terraform/appspec.yaml` |
| `compose_files` | Docker compose files | `docker-compose.yml docker-compose.ci.yml` |
| `terraform_version` | Terraform version | `1.7.0` |
| `aws_region` | AWS region | `eu-central-1` |
| `staging_ecs_service_name` | ECS service deployed by a rolling update **before** production (empty = no staging job) | `` |
| `staging_task_family` | Task definition family of that staging service | `` |

---

## 🧪 Staging service before production (optional)

A service that runs a second, non-CodeDeploy ECS service for staging (for example `render` with `render-staging`) can
have the pipeline deploy it first. Set both inputs; leave them out and nothing changes.

```yaml
jobs:
  deploy:
    uses: tec42/github-workflows/.github/workflows/reusable-service-deployment.yml@main
    with:
      service_name: render
      ecr_repository: render
      cluster_name: tec42-cluster-production
      ecs_service_name: render-production        # production: CodeDeploy Blue/Green
      task_family: render-production
      staging_ecs_service_name: render-staging   # staging: rolling update, deployed first
      staging_task_family: render-staging
      codedeploy_application: render-production-codedeploy-app
      codedeploy_deployment_group: render-production-deployment-group
```

How it behaves:

- The same image tag (from `release-ecr`) goes to both services.
- `deploy-staging` waits until the staging service is stable and confirms that it runs the new task definition. Give the
  staging service the **deployment circuit breaker with rollback**: a broken image is then rolled back by ECS, and the job
  reports it as a failure.
- A failed `deploy-staging` skips `deploy-ecs`: production does not start.
- Staging is the extra time of one rolling update (typically 2–5 minutes) per deployment.

---

## 🐛 Troubleshooting

### Deployment already in progress

**Error**: `❌ Deployment already in progress: d-XXXXXXXXX`

**Solution**: Wait for current deployment to finish or cancel manually:
```bash
aws deploy stop-deployment --deployment-id d-XXXXXXXXX --auto-rollback-enabled
```

---

### AppSpec not found

**Error**: `❌ AppSpec not found at: terraform/appspec.yaml`

**Solution**: Create `terraform/appspec.yaml` in your service repository (see Step 1).

---

### Task Definition not found

**Error**: `Task Definition not found: tec42-identity-task`

**Solution**: Ensure Terraform has created the Task Definition first:
```bash
cd terraform && terraform apply
```

---

### Health check timeout

**Symptom**: Workflow shows `⏰ Timeout after 3 minutes`

**This is expected!** The workflow uses hybrid wait strategy:
- Waits 3 minutes for initial health check
- Full deployment continues in background (10-15 minutes total)
- Check AWS Console for final status

---

### Rollback on failure

**Automatic**: CodeDeploy automatically rolls back if:
- Health checks fail
- Target group shows unhealthy targets
- Deployment times out

**Manual**:
```bash
aws deploy stop-deployment \
  --deployment-id d-XXXXXXXXX \
  --auto-rollback-enabled
```

---

## 📊 Monitoring

### GitHub Actions

```
Repository → Actions → Workflow Run
├─ Job 1: Release & ECR Push
├─ Job 2: Deploy Infrastructure
└─ Job 3: Deploy to ECS
    └─ Artifacts: terraform-plan (30 days)
```

### AWS Console

CodeDeploy:
```
https://eu-central-1.console.aws.amazon.com/codesuite/codedeploy/deployments/{deployment-id}
```

ECS:
```
https://eu-central-1.console.aws.amazon.com/ecs/v2/clusters/{cluster}/services/{service}
```

---

## ✅ Best Practices

1. **Pin workflow version**: Use `@v2.0.0` instead of `@main` in production
2. **Test in dev first**: Use separate ECS clusters for dev/prod
3. **Monitor deployments**: Set up CloudWatch alarms
4. **Keep appspec simple**: Only change when absolutely needed
5. **Terraform state locking**: Use DynamoDB lock table
6. **Secrets rotation**: Rotate AWS Secrets Manager secrets regularly
7. **Health check endpoint**: Implement `/health` endpoint in all services

---

## 🔗 Related Documentation

- [Terraform Deploy Workflow](../.github/workflows/reusable-terraform-deploy.yml)
- [ECS CodeDeploy Workflow](../.github/workflows/reusable-ecs-codedeploy.yml)
- [Master Orchestration Workflow](../.github/workflows/reusable-service-deployment.yml)
- [Service Deployment Architecture](https://github.com/yourusername/Architecture/blob/main/Service-Deployment.md)

---

**Questions?** Check [GitHub Discussions](https://github.com/ivodenwag/github-workflows/discussions) or open an issue.
