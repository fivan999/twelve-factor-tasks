#!/usr/bin/env bash
set -euo pipefail

namespace="focus"
secret_env="${SECRET_ENV:-deploy/k8s/secret.env}"

if [[ ! -f "$secret_env" ]]; then
  echo "Missing $secret_env. Copy deploy/k8s/secret.env.example and replace change-me." >&2
  exit 1
fi

kubectl apply -f deploy/k8s/00-namespace.yaml
kubectl -n "$namespace" create secret generic focus-secrets \
  --from-env-file="$secret_env" \
  --dry-run=client \
  -o yaml | kubectl apply -f -
kubectl apply -f deploy/k8s/01-config.yaml
kubectl apply -f deploy/k8s/02-postgres.yaml
kubectl -n "$namespace" rollout status deployment/postgres --timeout=180s

kubectl -n "$namespace" delete job focus-migrate --ignore-not-found --wait=true
kubectl apply -f deploy/k8s/03-migration-job.yaml
kubectl -n "$namespace" wait --for=condition=complete job/focus-migrate --timeout=180s

kubectl apply -f deploy/k8s/04-app.yaml
kubectl -n "$namespace" rollout status deployment/focus --timeout=180s
kubectl -n "$namespace" get pods,services,jobs,persistentvolumeclaims
