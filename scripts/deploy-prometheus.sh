#!/bin/bash
set -e

# Deploy Prometheus to EKS with AWS Managed Prometheus
# This script substitutes Terraform outputs into Kubernetes manifests

echo "=== Deploying Prometheus to EKS ==="

# Get Terraform outputs
echo "Fetching Terraform outputs..."
PROMETHEUS_ROLE_ARN=$(terraform output -raw prometheus_role_arn)
AMP_WORKSPACE_ENDPOINT=$(terraform output -raw prometheus_workspace_endpoint)
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")

if [ -z "$PROMETHEUS_ROLE_ARN" ] || [ -z "$AMP_WORKSPACE_ENDPOINT" ]; then
    echo "Error: Could not fetch Terraform outputs. Make sure Terraform has been applied."
    exit 1
fi

echo "Using:"
echo "  Role ARN: $PROMETHEUS_ROLE_ARN"
echo "  AMP Endpoint: $AMP_WORKSPACE_ENDPOINT"
echo "  Region: $AWS_REGION"

# Create temporary directory for processed manifests
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Process manifests
echo ""
echo "Processing Kubernetes manifests..."

# Copy and process serviceaccount
envsubst < k8s/prometheus-serviceaccount.yaml > $TMP_DIR/prometheus-serviceaccount.yaml \
    <<EOF
export PROMETHEUS_ROLE_ARN="$PROMETHEUS_ROLE_ARN"
EOF

# Copy and process config
envsubst < k8s/prometheus-config.yaml > $TMP_DIR/prometheus-config.yaml \
    <<EOF
export AMP_WORKSPACE_ENDPOINT="$AMP_WORKSPACE_ENDPOINT"
export AWS_REGION="$AWS_REGION"
EOF

# Copy other manifests as-is
cp k8s/prometheus-namespace.yaml $TMP_DIR/
cp k8s/prometheus-rbac.yaml $TMP_DIR/
cp k8s/prometheus-deployment.yaml $TMP_DIR/

# Apply manifests
echo ""
echo "Applying Kubernetes manifests..."
kubectl apply -f $TMP_DIR/prometheus-namespace.yaml
kubectl apply -f $TMP_DIR/prometheus-serviceaccount.yaml
kubectl apply -f $TMP_DIR/prometheus-rbac.yaml
kubectl apply -f $TMP_DIR/prometheus-config.yaml
kubectl apply -f $TMP_DIR/prometheus-deployment.yaml

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Check status with:"
echo "  kubectl get pods -n prometheus"
echo ""
echo "View logs with:"
echo "  kubectl logs -n prometheus -l app=prometheus-server"
echo ""
echo "Port-forward to access Prometheus UI:"
echo "  kubectl port-forward -n prometheus svc/prometheus-server 9090:9090"
