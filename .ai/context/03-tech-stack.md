# Tech Stack — github-workflows

**Version**: 1.0.0  
**Last Updated**: 26. März 2026

---

## Core Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| GitHub Actions | N/A | CI/CD platform |
| YAML | 1.2 | Workflow definition |
| Bash | 5.x | Script execution |
| Docker | 24.x | Container builds |
| AWS CLI | 2.x | AWS interactions |
| Terraform | 1.16.6 | Infrastructure deployment |

---

## GitHub Actions Features

### Workflow Types

| Type | Trigger | Usage |
|------|---------|-------|
| `workflow_call` | Called by other workflows | Reusable workflows (this repo) |
| `workflow_dispatch` | Manual trigger | On-demand execution |
| `push` | Git push | CI triggers |
| `pull_request` | PR events | PR validation |

### Key Actions Used

| Action | Version | Purpose |
|--------|---------|---------|
| `actions/checkout` | v4 | Clone repository |
| `actions/setup-node` | v4 | Node.js environment |
| `actions/upload-artifact` | v4 | Store build artifacts |
| `aws-actions/configure-aws-credentials` | v4 | AWS OIDC authentication |
| `aws-actions/amazon-ecr-login` | v2 | ECR authentication |
| `hashicorp/setup-terraform` | v3 | Terraform CLI |

---

## AWS Services

| Service | Purpose |
|---------|---------|
| ECR | Docker image registry |
| ECS | Container orchestration |
| CodeDeploy | Blue/Green deployments |
| IAM (OIDC) | Secure authentication |
| S3 | Terraform state backend |
| Secrets Manager | Application secrets |

---

## Release Tools

### release-it

Semantic versioning and release management.

**Configuration**: `shared/.release-it.json`

**Features**:
- Conventional Commits analysis
- Automatic version bumping (major/minor/patch)
- Git tag creation
- GitHub Release creation
- Changelog generation

**Commit Types**:
| Type | Version Bump | Section |
|------|-------------|---------|
| `feat:` | Minor | ✨ Features |
| `fix:` | Patch | 🐛 Bug Fixes |
| `perf:` | Patch | ⚡ Performance |
| `docs:` | None | 📚 Documentation |
| `refactor:` | None | ♻️ Refactoring |
| `test:` | None | 🧪 Tests |
| `chore:` | None | 🔧 Chores |
| `BREAKING CHANGE:` | Major | 💥 Breaking |

---

## Docker

### Build Strategy

```yaml
# Multi-stage build via docker-compose
docker compose -f docker-compose.yml build $SERVICE_NAME
```

### Image Tagging

| Tag | When | Example |
|-----|------|---------|
| Version | Release created | `v1.2.3` |
| Branch-SHA | No release | `main-a1b2c3d4` |

---

## Authentication

### AWS OIDC (No Static Credentials)

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: eu-central-1
    role-session-name: GitHubActions
```

**Benefits**:
- No access keys in secrets
- Short-lived credentials
- Audit trail via CloudTrail
- Role-based access control

---

## Further Documentation

[Overview](01-overview.md) | [Architecture](02-architecture.md) | [Development](07-development.md)
