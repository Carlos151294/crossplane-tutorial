{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:pkgs.mkShell {
  packages = with pkgs; [
    git
    gum
    gh
    kind
    kubectl
    yq-go
    jq
    (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
    awscli2
    azure-cli
    upbound
    teller
    crossplane-cli
    kubernetes-helm
  ];
}
