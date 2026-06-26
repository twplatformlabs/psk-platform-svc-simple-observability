#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster_role=$1

argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)
custom_chart_version=$(jq -er .custom_chart_version environments/$cluster_role.json)

echo "Application resource and configuration files for mimir"
echo "creating deploy-files directory for all the mimir files that will written to psk-platform-control-plane-configuration repository"
mkdir deploy-files/mimir

# generate application.yaml for both Applications then stage the files for writing to the app-of-app config repo
echo "generating mimir application.yaml"
cat <<EOF > deploy-files/mimir/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mimir
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://github.com/twplatformlabs/psk-platform-svc-simple-observability
      path: chart/mimir
      targetRevision: $custom_chart_version
      helm:
        valueFiles:
          - \$config/roles/$cluster_role/mimir/default-values.yaml
          - \$config/roles/$cluster_role/mimir/$cluster_role-values.yaml
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
cat deploy-files/mimir/application.yaml

echo "copying mimir values"
cp -v deploy-templates/mimir-default-values.yaml deploy-files/mimir/default-values.yaml
cp -v deploy-templates/mimir-$cluster_role-values.yaml deploy-files/mimir/$cluster_role-values.yaml
