#!/usr/bin/env bash
set -euo pipefail

image="localhost/twelve-factor-tasks:week2"
archive="build/twelve-factor-tasks-week2.tar"

mkdir -p build
podman build -t "$image" -f Containerfile .
podman save --format oci-archive -o "$archive" "$image"
minikube image load "$archive"
minikube image ls | grep -F "localhost/twelve-factor-tasks:week2"
