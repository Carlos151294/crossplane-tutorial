#!/bin/sh
# Fix Argo CD password issue by removing custom password and letting Argo CD generate one

set -e

gum style --foreground 212 --bold "Fixing Argo CD Password"

echo "Upgrading Argo CD to remove custom password..." | gum format
helm upgrade argocd argo-cd \
    --repo https://argoproj.github.io/argo-helm \
    --namespace argocd \
    --values argocd/helm-values.yaml \
    --wait

echo "Waiting for Argo CD server to be ready..." | gum format
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd

echo "Waiting for initial admin secret to be created..." | gum format
for i in {1..30}; do
    if kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

echo "" | gum format
gum style --foreground 212 --bold "Argo CD Password:"
echo "  Username: admin" | gum format
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
if [ -n "$PASSWORD" ]; then
    echo "  Password: $PASSWORD" | gum format
else
    echo "  Password: (Still generating... run this command in a moment:)" | gum format
    echo "    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" | gum format
fi
