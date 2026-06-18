#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster_role=$1

grafana_chart_version=$(jq -er .grafana_chart_version environments/$cluster_role.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

# perform trivy scan of chart with role configuration.
# ArgoCD Core will do the actual Helm install, this is just a pre-flight security review
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
trivyScan "grafana-community/grafana" "grafana" "$grafana_chart_version" "deploy-templates/grafana-default-values.yaml"

echo "Application resource and configuration files for grafana"
echo "grafana chart version: $grafana_chart_version"
echo "creating deploy-files directory for all the grafana files that will written to psk-platform-control-plane-configuration repository"
mkdir deploy-files/grafana

# generate application.yaml for both Applications then stage the files for writing to the app-of-app config repo
echo "generating grafana application.yaml"
cat <<EOF > deploy-files/grafana/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "4"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://grafana-community.github.io/helm-charts
      chart: grafana-community/grafana
      targetRevision: $grafana_chart_version
      helm:
        valueFiles:
          - \$config/roles/$cluster_role/grafana/default-values.yaml
          - \$config/roles/$cluster_role/grafana/$cluster_role-values.yaml
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
cat deploy-files/grafana/application.yaml

echo "copying default values"
cp -v deploy-templates/grafana-default-values.yaml deploy-files/grafana/default-values.yaml
cp -v deploy-templates/grafana-$cluster_role-values.yaml deploy-files/grafana/$cluster_role-values.yaml
