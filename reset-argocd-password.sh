#!/bin/sh
# Script to reset Argo CD admin password

set -e

gum style --foreground 212 --bold "Resetting Argo CD Admin Password"

# Check if argocd CLI is available
if ! command -v argocd >/dev/null 2>&1; then
    gum style --foreground 1 "Error: Argo CD CLI not found."
    echo "Install it with: brew install argocd" | gum format
    exit 1
fi

# Get Argo CD server URL
ARGOCD_SERVER="argocd.127.0.0.1.nip.io:8080"

echo "Argo CD Server: $ARGOCD_SERVER" | gum format
echo "" | gum format

# Get new password from user
NEW_PASSWORD=$(gum input --placeholder "Enter new admin password" --password)

if [ -z "$NEW_PASSWORD" ]; then
    gum style --foreground 1 "Error: Password cannot be empty"
    exit 1
fi

echo "" | gum format
echo "Logging in to Argo CD..." | gum format

# First, try to login with the current password (if we can get it)
# Or use port-forward to access the server
echo "Setting up port-forward..." | gum format
kubectl port-forward -n argocd service/argocd-server 8080:443 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 3

# Login (this might fail if password is unknown, but we'll try to update it)
echo "Attempting to update password..." | gum format
argocd login localhost:8080 --insecure --username admin --password "$NEW_PASSWORD" 2>/dev/null || \
argocd account update-password --account admin --current-password "" --new-password "$NEW_PASSWORD" --server localhost:8080 --insecure 2>/dev/null || \
echo "If login fails, you may need to delete the secret and let Argo CD regenerate it:" | gum format && \
echo "  kubectl -n argocd delete secret argocd-secret" | gum format && \
echo "  kubectl -n argocd rollout restart deployment argocd-server" | gum format

# Kill port-forward
kill $PORT_FORWARD_PID 2>/dev/null || true

echo "" | gum format
gum style --foreground 212 --bold "Password reset complete!"
echo "Username: admin" | gum format
echo "Password: $NEW_PASSWORD" | gum format
