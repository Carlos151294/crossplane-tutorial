#!/bin/sh
# Simple script to get or reset Argo CD password

gum style --foreground 212 --bold "Argo CD Password Helper"

echo "" | gum format
echo "Attempting to get password..." | gum format

# Try to get from initial secret first
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)

if [ -n "$PASSWORD" ]; then
    echo "Password found in initial secret:" | gum format
    echo "  Username: admin" | gum format
    echo "  Password: $PASSWORD" | gum format
    exit 0
fi

# If not found, the password is set via helm values (bcrypt hash)
echo "Initial secret not found. Password is set via helm values." | gum format
echo "" | gum format
echo "To reset the password, you have two options:" | gum format
echo "" | gum format
echo "Option 1: Delete and regenerate (simplest)" | gum format
echo "  kubectl -n argocd delete secret argocd-secret" | gum format
echo "  kubectl -n argocd rollout restart deployment argocd-server" | gum format
echo "  Then check: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" | gum format
echo "" | gum format
echo "Option 2: Use Argo CD CLI to change password" | gum format
echo "  1. kubectl port-forward -n argocd svc/argocd-server 8080:443" | gum format
echo "  2. argocd login localhost:8080 --insecure --username admin" | gum format
echo "  3. argocd account update-password" | gum format
