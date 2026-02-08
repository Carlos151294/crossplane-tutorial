#!/bin/sh
set -e

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'Setup for the Introduction chapter'

gum confirm '
Are you ready to start?
Select "Yes" only if you did NOT follow the story from the start (if you jumped straight into this chapter).
Feel free to say "No" and inspect the script if you prefer setting up resources manually.
' || exit 0

echo "
## You will need following tools installed:
|Name            |Required             |More info                                          |
|----------------|---------------------|---------------------------------------------------|
|Linux Shell     |Yes                  |Use WSL if you are running Windows                 |
|Docker          |Yes                  |'https://docs.docker.com/engine/install'           |
|kind CLI        |Yes                  |'https://kind.sigs.k8s.io/docs/user/quick-start/#installation'|
|kubectl CLI     |Yes                  |'https://kubernetes.io/docs/tasks/tools/#kubectl'  |
|crossplane CLI  |Yes                  |'https://docs.crossplane.io/latest/cli'            |
|yq CLI          |Yes                  |'https://github.com/mikefarah/yq#install'          |
|Google Cloud account with admin permissions|If using Google Cloud|'https://cloud.google.com'|
|Google Cloud CLI|If using Google Cloud|'https://cloud.google.com/sdk/docs/install'        |
|AWS account with admin permissions|If using AWS|'https://aws.amazon.com'                  |
|AWS CLI         |If using AWS         |'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'|
|Azure account with admin permissions|If using Azure|'https://azure.microsoft.com'         |
|az CLI          |If using Azure       |'https://learn.microsoft.com/cli/azure/install-azure-cli'|

If you are running this script from **Nix shell**, most of the requirements are already set with the exception of **Docker** and the **hyperscaler account**.
" | gum format

gum confirm "
Do you have those tools installed?
" || exit 0

rm -f .env

#########################
# Control Plane Cluster #
#########################

# Delete existing cluster if it exists
kind delete cluster --name kind 2>/dev/null || true

# Clean up any leftover Docker networks (kind creates a 'kind' network)
docker network rm kind 2>/dev/null || true

# Find and stop any containers using ports 8080 or 8443 (e.g., leftover kind containers)
for container in $(docker ps -a --format "{{.ID}} {{.Ports}}" 2>/dev/null | grep -E ":(8080|8443)->" | awk '{print $1}' || true); do
    docker stop "$container" 2>/dev/null || true
    docker rm "$container" 2>/dev/null || true
done

# Clean up Docker networks and prune unused resources
docker network prune -f 2>/dev/null || true

# Wait a moment for ports to be released
sleep 2

# Check if ports 8080 or 8443 are in use and provide helpful error
if lsof -iTCP:8080 -sTCP:LISTEN -P >/dev/null 2>&1 || lsof -iTCP:8443 -sTCP:LISTEN -P >/dev/null 2>&1; then
    gum style --foreground 1 --bold "ERROR: Ports 8080 or 8443 are already in use. Please stop the service using these ports and try again."
    echo "You can check what's using these ports with: lsof -iTCP:8080 -iTCP:8443 -sTCP:LISTEN" | gum format
    exit 1
fi

kind create cluster --config kind.yaml

kubectl apply \
    --filename https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

##############
# Crossplane #
##############

helm upgrade --install crossplane crossplane \
    --repo https://charts.crossplane.io/stable \
    --namespace crossplane-system --create-namespace --wait

# Wait for Provider CRD to be ready before applying providers
echo "Waiting for Crossplane CRDs to be ready..." | gum format
kubectl wait --for condition=established --timeout=60s crd providers.pkg.crossplane.io 2>/dev/null || true
kubectl wait --for condition=established --timeout=60s crd deploymentruntimeconfigs.pkg.crossplane.io 2>/dev/null || true

# Apply provider resources
kubectl apply --filename providers/provider-kubernetes-incluster.yaml

# Wait for provider deployment to be created, then patch it with service account
kubectl wait --for condition=available --timeout=120s deployment -n crossplane-system -l pkg.crossplane.io/provider=provider-kubernetes 2>/dev/null || true
kubectl patch deployment -n crossplane-system -l pkg.crossplane.io/provider=provider-kubernetes --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/serviceAccountName", "value": "crossplane-provider-kubernetes"}]' 2>/dev/null || true

kubectl apply --filename providers/provider-helm-incluster.yaml

# Wait for helm provider deployment and patch it
kubectl wait --for condition=available --timeout=120s deployment -n crossplane-system -l pkg.crossplane.io/provider=provider-helm 2>/dev/null || true
kubectl patch deployment -n crossplane-system -l pkg.crossplane.io/provider=provider-helm --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/serviceAccountName", "value": "crossplane-provider-helm"}]' 2>/dev/null || true

kubectl apply --filename providers/dot-kubernetes.yaml

kubectl apply --filename providers/dot-sql.yaml

kubectl apply --filename providers/dot-app.yaml

gum spin --spinner dot \
    --title "Waiting for Crossplane providers..." -- sleep 60

kubectl wait --for=condition=healthy provider.pkg.crossplane.io \
    --all --timeout=1800s

echo "## Which Hyperscaler do you want to use?" | gum format

HYPERSCALER=$(gum choose "google" "aws" "azure")

echo "export HYPERSCALER=$HYPERSCALER" >> .env

if [[ "$HYPERSCALER" == "google" ]]; then

    gcloud auth login

    PROJECT_ID=dot-20260207173630

    echo "export PROJECT_ID=$PROJECT_ID" >> .env

    # gcloud projects create ${PROJECT_ID}

    # echo "## Open https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID and link a billing account" \
    #     | gum format

    # gum input --placeholder "Press the enter key to continue."

    # echo "## Open https://console.cloud.google.com/marketplace/product/google/container.googleapis.com?project=$PROJECT_ID and *ENABLE* the API" \
    #     | gum format

    # gum input --placeholder "Press the enter key to continue."

    # echo "## Open https://console.cloud.google.com/apis/library/sqladmin.googleapis.com?project=$PROJECT_ID and *ENABLE* the API" \
    #     | gum format

    # gum input --placeholder "Press the enter key to continue."

    export SA_NAME=devops-toolkit

    export SA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

    # Create service account if it doesn't exist
    if ! gcloud iam service-accounts describe $SA --project $PROJECT_ID >/dev/null 2>&1; then
        gcloud iam service-accounts create $SA_NAME \
            --project $PROJECT_ID
    else
        echo "Service account $SA already exists, skipping creation." | gum format
    fi

    export ROLE=roles/admin

    # Add IAM policy binding if it doesn't exist
    if ! gcloud projects get-iam-policy $PROJECT_ID \
        --flatten="bindings[].members" \
        --filter="bindings.members:serviceAccount:$SA AND bindings.role:$ROLE" \
        --format="value(bindings.role)" | grep -q "$ROLE"; then
        gcloud projects add-iam-policy-binding \
            --role $ROLE $PROJECT_ID --member serviceAccount:$SA
    else
        echo "IAM policy binding already exists, skipping." | gum format
    fi

    # Create service account key if it doesn't exist
    if [ ! -f gcp-creds.json ]; then
        gcloud iam service-accounts keys create gcp-creds.json \
            --project $PROJECT_ID --iam-account $SA
    else
        echo "Service account key file gcp-creds.json already exists, skipping creation." | gum format
    fi

    # Wait for cluster to be ready and create/update secret
    echo "Waiting for cluster to be ready..." | gum format
    kubectl cluster-info >/dev/null 2>&1 || sleep 5
    
    # Check if secret already exists, if so update it, otherwise create it
    if kubectl --namespace crossplane-system get secret gcp-creds >/dev/null 2>&1; then
        echo "Secret gcp-creds already exists, updating..." | gum format
        kubectl --namespace crossplane-system \
            create secret generic gcp-creds \
            --from-file creds=./gcp-creds.json \
            --dry-run=client -o yaml | kubectl apply -f -
    else
        # Retry secret creation with exponential backoff
        for i in {1..5}; do
            if kubectl --namespace crossplane-system \
                create secret generic gcp-creds \
                --from-file creds=./gcp-creds.json 2>/dev/null; then
                break
            fi
            if [ $i -eq 5 ]; then
                echo "Failed to create secret after 5 attempts." | gum format
                exit 1
            else
                sleep $((i * 2))
            fi
        done
    fi

    echo "
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  projectID: $PROJECT_ID
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: gcp-creds
      key: creds" | kubectl apply --filename -

elif [[ "$HYPERSCALER" == "aws" ]]; then

    AWS_ACCESS_KEY_ID=$(gum input --placeholder "AWS Access Key ID" --value "$AWS_ACCESS_KEY_ID")
    echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> .env
    
    AWS_SECRET_ACCESS_KEY=$(gum input --placeholder "AWS Secret Access Key" --value "$AWS_SECRET_ACCESS_KEY" --password)
    echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> .env

    AWS_ACCOUNT_ID=$(gum input --placeholder "AWS Account ID" --value "$AWS_ACCOUNT_ID")
    echo "export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID" >> .env

    echo "[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
" >aws-creds.conf

    # Check if secret already exists, if so update it, otherwise create it
    if kubectl --namespace crossplane-system get secret aws-creds >/dev/null 2>&1; then
        echo "Secret aws-creds already exists, updating..." | gum format
        kubectl --namespace crossplane-system \
            create secret generic aws-creds \
            --from-file creds=./aws-creds.conf \
            --dry-run=client -o yaml | kubectl apply -f -
    else
        # Retry secret creation with exponential backoff
        for i in {1..5}; do
            if kubectl --namespace crossplane-system \
                create secret generic aws-creds \
                --from-file creds=./aws-creds.conf 2>/dev/null; then
                break
            fi
            if [ $i -eq 5 ]; then
                echo "Failed to create secret after 5 attempts." | gum format
                exit 1
            else
                sleep $((i * 2))
            fi
        done
    fi

    kubectl apply --filename providers/aws-config.yaml

else

    AZURE_TENANT_ID=$(gum input --placeholder "Azure Tenant ID" --value "$AZURE_TENANT_ID")

    az login --tenant $AZURE_TENANT_ID

    export SUBSCRIPTION_ID=$(az account show --query id -o tsv)

    az ad sp create-for-rbac --sdk-auth --role Owner --scopes /subscriptions/$SUBSCRIPTION_ID | tee azure-creds.json

    # Check if secret already exists, if so update it, otherwise create it
    if kubectl --namespace crossplane-system get secret azure-creds >/dev/null 2>&1; then
        echo "Secret azure-creds already exists, updating..." | gum format
        kubectl --namespace crossplane-system \
            create secret generic azure-creds \
            --from-file creds=./azure-creds.json \
            --dry-run=client -o yaml | kubectl apply -f -
    else
        # Retry secret creation with exponential backoff
        for i in {1..5}; do
            if kubectl --namespace crossplane-system create secret generic azure-creds --from-file creds=./azure-creds.json 2>/dev/null; then
                break
            fi
            if [ $i -eq 5 ]; then
                echo "Failed to create secret after 5 attempts." | gum format
                exit 1
            else
                sleep $((i * 2))
            fi
        done
    fi

    kubectl apply --filename providers/azure-config.yaml

    DB_NAME=silly-demo-db-$(date +%Y%m%d%H%M%S)

    echo "---
apiVersion: devopstoolkitseries.com/v1alpha1
kind: ClusterClaim
metadata:
  name: cluster-01
spec:
  id: cluster01
  compositionSelector:
    matchLabels:
      provider: azure
      cluster: aks
  parameters:
    nodeSize: small
    minNodeCount: 3
---
apiVersion: v1
kind: Secret
metadata:
  name: $DB_NAME-password
data:
  password: SVdpbGxOZXZlclRlbGxAMQ==
---
apiVersion: devopstoolkitseries.com/v1alpha1
kind: SQLClaim
metadata:
  name: silly-demo-db
spec:
  id: $DB_NAME
  compositionSelector:
    matchLabels:
      provider: azure
      db: postgresql
  parameters:
    version: \"11\"
    size: small
---
apiVersion: devopstoolkitseries.com/v1alpha1
kind: AppClaim
metadata:
  name: silly-demo
spec:
  id: silly-demo
  compositionSelector:
    matchLabels:
      type: backend-db
      location: remote
  parameters:
    namespace: production
    image: c8n.io/vfarcic/silly-demo:1.4.52
    port: 8080
    host: silly-demo.acme.com
    dbSecret:
      name: silly-demo-db
      namespace: a-team
    kubernetesProviderConfigName: cluster01" \
    | tee examples/azure-intro.yaml

fi

kubectl create namespace a-team

###########
# Argo CD #
###########

REPO_URL=$(git config --get remote.origin.url)
# workaround to avoid setting up SSH key in ArgoCD
REPO_URL=$(echo $REPO_URL | sed 's/git@github.com:/https:\/\/github.com\//') # replace git@github.com: to https://github.com/

yq --inplace ".spec.source.repoURL = \"$REPO_URL\"" argocd/apps.yaml

helm upgrade --install argocd argo-cd \
    --repo https://argoproj.github.io/argo-helm \
    --namespace argocd --create-namespace \
    --values argocd/helm-values.yaml --wait

kubectl apply --filename argocd/apps.yaml

# Display Argo CD access information
echo "" | gum format
gum style --foreground 212 --bold "Argo CD has been installed!"
echo "" | gum format
echo "You can access Argo CD using one of the following methods:" | gum format
echo "" | gum format
echo "1. Via Ingress (recommended):" | gum format
echo "   http://argocd.127.0.0.1.nip.io:8080" | gum format
echo "" | gum format
echo "2. Via port-forward:" | gum format
echo "   kubectl port-forward service/argocd-server -n argocd 8080:443" | gum format
echo "   Then open: https://localhost:8080 (accept the certificate warning)" | gum format
echo "" | gum format
echo "Default credentials:" | gum format
echo "  Username: admin" | gum format
# Try to get password from initial secret first, otherwise check if custom password is set
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
if [ -z "$PASSWORD" ]; then
    echo "  Password: (Custom password set in helm values)" | gum format
    echo "" | gum format
    echo "  To reset the password, run:" | gum format
    echo "    argocd account update-password --account admin --new-password YOUR_NEW_PASSWORD" | gum format
    echo "  Or use the Argo CD CLI to login and change it via UI" | gum format
else
    echo "  Password: $PASSWORD" | gum format
fi
