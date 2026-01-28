# Deployment Scripts

This directory contains helper scripts for deploying and managing the EKS cluster and its components.

## Available Scripts

### deploy-prometheus.sh

Deploys Prometheus to the EKS cluster with AWS Managed Prometheus integration.

**Prerequisites:**
- Terraform has been applied successfully
- kubectl is configured for the EKS cluster
- `envsubst` command is available (usually part of gettext package)

**Usage:**
```bash
./scripts/deploy-prometheus.sh
```

**What it does:**
1. Fetches Terraform outputs (IAM role ARN, AMP workspace endpoint, AWS region)
2. Substitutes these values into Kubernetes manifests
3. Applies all Prometheus manifests to the cluster
4. Provides verification commands

**Environment Variables:**
The script automatically fetches values from Terraform, but you can override them:
- `PROMETHEUS_ROLE_ARN` - IAM role ARN for Prometheus service account
- `AMP_WORKSPACE_ENDPOINT` - AWS Managed Prometheus workspace endpoint
- `AWS_REGION` - AWS region (defaults to us-west-2)

**Example with overrides:**
```bash
export PROMETHEUS_ROLE_ARN="arn:aws:iam::123456789012:role/my-role"
export AMP_WORKSPACE_ENDPOINT="https://aps-workspaces.us-west-2.amazonaws.com/workspaces/ws-xxx/"
./scripts/deploy-prometheus.sh
```

## Installing envsubst

If `envsubst` is not available on your system:

**macOS:**
```bash
brew install gettext
brew link --force gettext
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install gettext
```

**Linux (RHEL/CentOS):**
```bash
sudo yum install gettext
```

## Adding New Scripts

When adding new scripts to this directory:

1. Make them executable: `chmod +x scripts/your-script.sh`
2. Add a shebang: `#!/bin/bash`
3. Use `set -e` to exit on errors
4. Document the script in this README
5. Add usage examples and prerequisites
