#!/usr/bin/env bats

# ------------------------------------- obs-dependencies
@test "cluster-info is mirrored" {
  run bash -c "kubectl get cm -n observe -o wide"
  [[ "${output}" =~ "cluster-info" ]]
}

@test "loki pvc ready" {
  run bash -c "kubectl get efspvc loki-wal -n observe"
  [[ ! "${output}" =~ "False" ]]
}

@test "tempo pvc ready" {
  run bash -c "kubectl get efspvc tempo-wal -n observe"
  [[ ! "${output}" =~ "False" ]]
}

@test "grafana pvc ready" {
  run bash -c "kubectl get efspvc grafana-pvc -n observe"
  [[ ! "${output}" =~ "False" ]]
}

@test "loki-wal Bound" {
  run bash -c "kubectl get pvc loki-wal -n observe"
  [[ "${output}" =~ "Bound" ]]
}

@test "tempo-wal Bound" {
  run bash -c "kubectl get pvc tempo-wal -n observe"
  [[ "${output}" =~ "Bound" ]]
}

@test "grafana-pvc Bound" {
  run bash -c "kubectl get pvc grafana-pvc -n observe"
  [[ "${output}" =~ "Bound" ]]
}

@test "loki s3bucket" {
  run bash -c "kubectl get s3buckets loki -n observe"
  [[ ! "${output}" =~ "False" ]]
}

@test "mimir s3bucket" {
  run bash -c "kubectl get s3buckets mimir -n observe"
  [[ ! "${output}" =~ "False" ]]
}

@test "tempo s3bucket" {
  run bash -c "kubectl get s3buckets tempo -n observe"
  [[ ! "${output}" =~ "False" ]]
}

# ------------------------------------- loki

@test "loki statefulset" {
  run bash -c "kubectl get po loki-0 -n observe"
  [[ "${output}" =~ "Running" ]]
  [[ "${output}" =~ "2/2" ]]
}

@test "loki daemonset" {
  run bash -c "kubectl get pods -l app.kubernetes.io/component=canary,app.kubernetes.io/name=loki -n observe"
  [[ "${output}" =~ "Running" ]]
}

@test "loki deployment" {
  run bash -c "kubectl get pods -l app.kubernetes.io/component=gateway,app.kubernetes.io/name=loki -n observe"
  [[ "${output}" =~ "Running" ]]
  [[ "${output}" =~ "2/2" ]]
}

# ------------------------------------- mimir

@test "mimir statefulset" {
  run bash -c "kubectl get po mimir-0 -n observe"
  [[ "${output}" =~ "Running" ]]
}

# ------------------------------------- tempo

@test "tempo statefulset" {
  run bash -c "kubectl get po tempo-0 -n observe"
  [[ "${output}" =~ "Running" ]]
}

# ------------------------------------- otel-collectors

@test "otel-daemonset" {
  run bash -c "kubectl get pods -l app.kubernetes.io/instance=otel-daemonset -n observe"
  [[ "${output}" =~ "Running" ]]
}

@test "otel-singleton" {
  run bash -c "kubectl get pods -l app.kubernetes.io/instance=otel-singleton -n observe"
  [[ "${output}" =~ "Running" ]]
}

# ------------------------------------- grafana

@test "grafana" {
  run bash -c "kubectl get pods -l app.kubernetes.io/instance=grafana -n observe"
  [[ "${output}" =~ "Running" ]]
}
