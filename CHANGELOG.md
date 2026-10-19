# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **reusable-ecs-rolling.yml** — deploys an ECS service by a rolling update (INVEST-005/EPIC-007/FEATURE-002/US-004)
  - Registers a new task definition from the latest revision of the family, waits until the service is stable, and
    confirms that the rollout is `COMPLETED` and the new task definition is the one running. A rollback by the ECS
    deployment circuit breaker fails the job.
- **reusable-service-deployment.yml** — optional inputs `staging_ecs_service_name` and `staging_task_family`
  - A new job `deploy-staging` runs before `deploy-ecs`; `deploy-ecs` starts only when it succeeded or was skipped.
  - Both inputs default to `''`: without them the job is skipped and a service deploys exactly as before.

## [2.1.0] - 2026-04-22

### Added
- **reusable-trigger-api-gateway-deploy.yml** — Triggers `workflow_dispatch` on `ivodenwag/tf-aws-api`
  - Input: `service_name` (e.g. `identity`, `cook`)
  - Requires `GH_PAT` secret with workflow write permissions on tf-aws-api
  - Fails with exit 1 if dispatch returns non-204 HTTP status

## [2.0.0] - 2026-02-06

### Added
- **reusable-service-deployment.yml** - Master orchestration workflow
- **reusable-terraform-deploy.yml** - Terraform infrastructure deployment
- **reusable-ecs-codedeploy.yml** - ECS Blue/Green deployment via CodeDeploy
- Complete ECS CodeDeploy integration with Blue/Green strategy
- Active deployment check (prevents concurrent deployments)
- Hybrid wait strategy (3 min initial health check + background)
- Service ownership principle (services provide appspec.yaml)
- Terraform plan artifact upload (30 days retention, audit trail)
- AWS OIDC authentication (no static credentials)
- Error handling with conditional job execution
- GitHub Step Summaries for all workflows
- AWS Console links in deployment summaries
- Comprehensive documentation and examples

### Changed
- Service workflows now use master orchestration workflow
- Simplified service repository workflow files (only configuration)
- Task Definition updates preserve secrets (downloaded + image update only)
- Workflow versioning best practice (@v2.0.0 instead of @main)

### Documentation
- Added examples/deploy-ecs-with-codedeploy.md (complete guide)
- Updated README.md with all workflow descriptions
- Added workflow versioning strategy
- Added security and monitoring sections
- Services must provide terraform/appspec.yaml (Service Ownership)

## [Unreleased]

### Added
- **reusable-terraform-deploy.yml — Cross-product media IAM deny check**: Added a step after Terraform Apply that runs `scripts/verify-media-iam-isolation.sh` from the calling service's `terraform_dir` if the file is present, feature-detected by file existence rather than named Terraform outputs; skips cleanly (no failure) for every other consumer of the reusable workflow that doesn't define this script
  - Ref: INVEST-005-EPIC-006-FEATURE-002-US-004

### Changed
- Simplified to 2-stage approach: development and production (removed QA stage)
- Migrated from npm-based CI to Docker Compose based CI
- All commands now execute via Makefile for consistency
- Removed node-version and working-directory inputs (defined in Dockerfile)
- Version detection from Git tags for production releases
- Coverage reports stored as GitHub Artifacts instead of Codecov

### Added
- Docker Compose support for multi-container environments (DB, Redis, etc.)
- Automatic version tagging from Git tags (v1.0.0)
- Docker image labels with version and commit information
- ECR deployment workflow (reusable-deploy-ecr.yml)
- Production release summary in workflow output
- Coverage summary displayed in GitHub Actions UI

### Removed
- QA environment support
- Codecov integration (replaced with GitHub Artifacts)
- Direct npm command execution (now via Make)

## [1.0.0] - 2026-01-02

### Added
- Initial release of centralized GitHub Actions workflows
- Reusable CI workflow for Node.js projects
- Environment-specific configurations
- Documentation and usage examples
