#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster=$1
cluster_role=$2

argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)
custom_chart_version=$(jq -er .custom_chart_version environments/$cluster_role.json)
loki_chart_version=$(jq -er .loki_chart_version environments/$cluster_role.json)
otel_chart_version=$(jq -er .otel_chart_version environments/$cluster_role.json)
grafana_chart_version=$(jq -er .grafana_chart_version environments/$cluster_role.json)

echo "svc-simple-observability health test"
echo "argocd namespace $argocd_namespace"
echo "custom_chart_version $custom_chart_version"
echo "loki_chart_version $loki_chart_version"
echo "otel_chart_version $otel_chart_version"
echo "grafana_chart_version $grafana_chart_version"

# confirm new version has been synced
# rolling update requires some time
sleep 480

# run basic smoketest for observability stack health
bats test/obs-service-check.bats

echo "validate argocd Application reconcilation for syncWaves 2"
validate_argocore_helm_app_resource "$argocd_namespace" "obs-dependencies" "$custom_chart_version"

echo "validate argocd Application reconcilation for syncWaves 3"
validate_argocore_helm_app_resource "$argocd_namespace" "loki" "$loki_chart_version"
validate_argocore_helm_app_resource "$argocd_namespace" "mimir" "$custom_chart_version"
validate_argocore_helm_app_resource "$argocd_namespace" "tempo" "$custom_chart_version"

echo "validate argocd Application reconcilation for syncWaves 4"
validate_argocore_helm_app_resource "$argocd_namespace" "otel-daemonset" "$otel_chart_version"
validate_argocore_helm_app_resource "$argocd_namespace" "otel-singleton" "$otel_chart_version"
validate_argocore_helm_app_resource "$argocd_namespace" "grafana" "$grafana_chart_version"

echo "Running validation job for observability components"
echo "Job will generate logs, events, metrics, and traces then"
echo "check for expected collection results across all backends"
TEST_FILES=("test/validate-observability-job.yaml")
cleanup() {
  echo "Deleting test files..."
  for f in "${TEST_FILES[@]}"; do
    kubectl delete -f "$f" --ignore-not-found=true
    echo "  removed: $f"
  done
}
trap cleanup EXIT INT TERM

kubectl apply -f test/validate-observability-job.yaml

for i in $(seq 1 90); do
  STATUS=$(kubectl -n observe get job otel-test \
    -o jsonpath='{.status.conditions[*].type}' 2>/dev/null)
  case "$STATUS" in
    *Complete*) 
      echo "otel-test PASSED"
      exit 0 
      ;;
    *Failed*)   
      echo "otel-test FAILED"
      kubectl -n observe logs job/otel-test -c verify --tail=-1
      exit 1 
      ;;
  esac
  echo ".... waiting for otel-test (attempt $i/90)"
  sleep 10
done

echo "otel-test TIMED OUT after 15 minutes"
exit 1
