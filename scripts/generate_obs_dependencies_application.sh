#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster_role=$1

argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)
custom_chart_version=$(jq -er .custom_chart_version environments/$cluster_role.json)

echo "Application resource and configuration files for on-cluster observability services"
echo "role: $cluster_role"
echo "creating deploy-files directory for obs-dependencies files that will written to psk-platform-control-plane-configuration repository"
mkdir deploy-files
mkdir deploy-files/obs-dependencies

# generate application.yaml for both Applications then stage the files for writing to the app-of-app config repo
echo "generating obs-dependencies application.yaml"
cat <<EOF > deploy-files/obs-dependencies/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: obs-dependencies
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://github.com/twplatformlabs/psk-platform-svc-simple-observability
      path: chart/obs-dependencies
      targetRevision: $custom_chart_version
      helm:
        valueFiles:
          - \$config/roles/$cluster_role/obs-dependencies/deps-default-values.yaml
          - \$config/roles/$cluster_role/obs-dependencies/deps-$cluster_role-values.yaml
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
      - CreateNamespace=true
      - SkipDryRunOnMissingResource=true
    managedNamespaceMetadata:
      labels:
        app.kubernetes.io/managed-by: psk-platform-svc-simple-observability
        platform-vault: "true"
    retry:
      limit: 5
      backoff:
        duration: 30s
        factor: 2
        maxDuration: 5m
EOF
cat deploy-files/obs-dependencies/application.yaml

echo "copying orb-dependency values"
cp -v deploy-templates/deps-default-values.yaml deploy-files/obs-dependencies/deps-default-values.yaml
cp -v deploy-templates/deps-$cluster_role-values.yaml deploy-files/obs-dependencies/deps-$cluster_role-values.yaml

