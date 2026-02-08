#!/bin/sh
set -e

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'Destruction of the Introduction chapter'

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
|AWS account with admin permissions|If using AWS|'https://aws.amazon.com'                  |
|AWS CLI         |If using AWS         |'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'|
|Google Cloud account with admin permissions|If using Google Cloud|'https://cloud.google.com'|
|Google Cloud CLI|If using Google Cloud|'https://cloud.google.com/sdk/docs/install'        |
|Azure account with admin permissions|If using Azure|'https://azure.microsoft.com'         |
|az CLI          |If using Azure       |'https://learn.microsoft.com/cli/azure/install-azure-cli'|

If you are running this script from **Nix shell**, most of the requirements are already set with the exception of **Docker** and the **hyperscaler account**.
" | gum format

gum confirm "
Do you have those tools installed?
" || exit 0

##############
# Crossplane #
##############

rm -f a-team/intro.yaml

git add .

git commit -m "Remove intro"

git push

COUNTER=$(kubectl get managed --no-headers | grep -v database \
	| grep -v object | grep -v release | wc -l)

MAX_WAIT=20  # Maximum number of iterations (20 * 30s = 10 minutes)
ITERATION=0

while [ $COUNTER -ne 0 ] && [ $ITERATION -lt $MAX_WAIT ]; do
	echo "$COUNTER resources still exist. Waiting for them to be deleted... (iteration $((ITERATION + 1))/$MAX_WAIT)"
	
	# Check for GCP clusters with deletion protection and disable it
	kubectl get managed -o name | grep "cluster.container.gcp.upbound.io" | while read resource; do
		DEL_PROT=$(kubectl get "$resource" -o jsonpath='{.spec.forProvider.deletionProtection}' 2>/dev/null)
		if [ "$DEL_PROT" = "true" ]; then
			echo "Disabling deletion protection on $resource..."
			kubectl patch "$resource" -p '{"spec":{"forProvider":{"deletionProtection":false}}}' --type=merge 2>/dev/null || true
		fi
	done
	
	sleep 30
	ITERATION=$((ITERATION + 1))
	COUNTER=$(kubectl get managed --no-headers \
		| grep -v database | grep -v object | grep -v release \
		| wc -l)
done

if [ $COUNTER -ne 0 ]; then
	echo "Warning: $COUNTER resources still exist after maximum wait time."
	echo "You may need to manually delete them or check for deletion protection issues."
	kubectl get managed --no-headers | grep -v database | grep -v object | grep -v release
	exit 1
fi

if [[ "$HYPERSCALER" == "google" ]]; then

	gcloud projects delete $PROJECT_ID --quiet

fi

#########################
# Control Plane Cluster #
#########################

kind delete cluster

##################
# Commit Changes #
##################

git add .

git commit -m "Chapter end"

git push
