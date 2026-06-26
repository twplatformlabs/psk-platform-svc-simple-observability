#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster_role=$1

argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)
custom_chart_version=$(jq -er .custom_chart_version environments/$cluster_role.json)

echo "Application resource and configuration files for tempo"
echo "creating deploy-files directory for all the tempo files that will written to psk-platform-control-plane-configuration repository"
mkdir deploy-files/tempo

# generate application.yaml for both Applications then stage the files for writing to the app-of-app config repo
echo "generating tempo application.yaml"
cat <<EOF > deploy-files/tempo/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tempo
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://github.com/twplatformlabs/psk-platform-svc-simple-observability
      path: chart/tempo
      targetRevision: $custom_chart_version
      helm:
        valueFiles:
          - \$config/roles/$cluster_role/tempo/default-values.yaml
          - \$config/roles/$cluster_role/tempo/$cluster_role-values.yaml
    - repoURL: https://github.com/twplatformlabs/psk-aws-control-plane-configuration
      targetRevision: HEAD
      ref: config
  destination:
    server: https://kubernetes.default.svc
    namespace: observe
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 30s
        factor: 2
        maxDuration: 5m
EOF
cat deploy-files/tempo/application.yaml

echo "copying tempo values"
cp -v deploy-templates/tempo-default-values.yaml deploy-files/tempo/default-values.yaml
cp -v deploy-templates/tempo-$cluster_role-values.yaml deploy-files/tempo/$cluster_role-values.yaml
