#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster_role=$1

loki_chart_version=$(jq -er .loki_chart_version environments/$cluster_role.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

# perform trivy scan of chart with role configuration.
# ArgoCD Core will do the actual Helm install, this is just a pre-flight security review
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
trivyScan "grafana-community/loki" "loki" "$loki_chart_version" "deploy-templates/loki-default-values.yaml"

echo "Application resource and configuration files for loki"
echo "loki chart version: $loki_chart_version"
echo "creating deploy-files directory for all the loki files that will written to psk-platform-control-plane-configuration repository"
mkdir deploy-files/loki

# generate application.yaml for both Applications then stage the files for writing to the app-of-app config repo
echo "generating loki application.yaml"
cat <<EOF > deploy-files/loki/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: loki
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://grafana-community.github.io/helm-charts
      chart: loki
      targetRevision: $loki_chart_version
      helm:
        valueFiles:
          - \$config/roles/$cluster_role/loki/default-values.yaml
          - \$config/roles/$cluster_role/loki/$cluster_role-values.yaml
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
cat deploy-files/loki/application.yaml

echo "copying default values"
cp -v deploy-templates/loki-default-values.yaml deploy-files/loki/default-values.yaml
cp -v deploy-templates/loki-$cluster_role-values.yaml deploy-files/loki/$cluster_role-values.yaml
