#!/usr/bin/env bash
set -euo pipefail

base_image="${MINIKUBE_BASE_IMAGE:-docker.io/kicbase/stable:v0.0.51}"

for command in podman minikube kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing required command: $command" >&2
    exit 1
  fi
done

if [[ "$(podman info --format '{{.Host.Security.Rootless}}')" != "false" ]]; then
  echo "Minikube with the Podman driver requires an active rootful Podman connection on macOS." >&2
  echo "See the Minikube section in README.md." >&2
  exit 1
fi

if ! minikube status >/dev/null 2>&1; then
  minikube config set rootless false
  minikube start \
    --driver=podman \
    --container-runtime=cri-o \
    --base-image="$base_image" \
    --cpus=2 \
    --memory=4096 \
    --preload=false
fi

./scripts/minikube-build.sh
./scripts/k8s-deploy.sh

echo "Run 'minikube service focus -n focus --url' to obtain the application URL."
