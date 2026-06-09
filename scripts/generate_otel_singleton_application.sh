#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster_role=$1

otel_chart_version=$(jq -er .otel_chart_version environments/$cluster_role.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

# perform trivy scan of chart with role configuration.
# ArgoCD Core will do the actual Helm install, this is just a pre-flight security review
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
trivyScan "open-telemetry/opentelemetry-collector" "opentelemetry-collector" "$otel_chart_version" "deploy-templates/otel-singleton-default-values.yaml"

echo "Application resource and configuration files for otel-singleton"
echo "otel chart version: $otel_chart_version"
echo "creating deploy-files directory for all the otel-singleton files that will written to psk-platform-control-plane-configuration repository"
mkdir deploy-files/otel-singleton

# generate application.yaml for both Applications then stage the files for writing to the app-of-app config repo
echo "generating otel-singleton application.yaml"
cat <<EOF > deploy-files/otel-singleton/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: otel-singleton
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "4"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://open-telemetry.github.io/opentelemetry-helm-charts
      chart: open-telemetry/opentelemetry-collector
      targetRevision: $otel_chart_version
      helm:
        valueFiles:
          - \$config/roles/$cluster_role/otel-singleton/default-values.yaml
          - \$config/roles/$cluster_role/otel-singleton/$cluster_role-values.yaml
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
cat deploy-files/otel-singleton/application.yaml

echo "copying default values"
cp -v deploy-templates/otel-singleton-default-values.yaml deploy-files/otel-singleton/default-values.yaml
cp -v deploy-templates/otel-singleton-$cluster_role-values.yaml deploy-files/otel-singleton/$cluster_role-values.yaml
