#!/bin/sh
# Diagnostic script for kind cluster issues

gum style --foreground 212 --bold "=== Kind Cluster Diagnostics ==="

echo "" | gum format
echo "1. Checking Docker resources..." | gum format
docker stats --no-stream kind-control-plane 2>/dev/null || echo "  ⚠️  Cannot get Docker stats"

echo "" | gum format
echo "2. Checking cluster nodes..." | gum format
kubectl get nodes 2>&1 | head -5

echo "" | gum format
echo "3. Checking API server connectivity..." | gum format
timeout 10 kubectl cluster-info 2>&1 || echo "  ⚠️  API server timeout"

echo "" | gum format
echo "4. Checking system pods..." | gum format
kubectl get pods -n kube-system 2>&1 | head -10

echo "" | gum format
echo "5. Checking Argo CD pods..." | gum format
kubectl get pods -n argocd 2>&1 | head -10

echo "" | gum format
echo "6. Checking for resource constraints..." | gum format
kubectl top nodes 2>&1 || echo "  ⚠️  Metrics server not available"

echo "" | gum format
gum style --foreground 212 --bold "=== Recommendations ==="
echo "If you see timeouts or errors:" | gum format
echo "1. Increase Docker Desktop resources (CPU/Memory)" | gum format
echo "2. Restart Docker Desktop" | gum format
echo "3. Restart the cluster: kind delete cluster && kind create cluster --config kind.yaml" | gum format
echo "4. Check Docker logs: docker logs kind-control-plane" | gum format
