#!/usr/bin/env bash
set -euo pipefail

if ! command -v kubeconform >/dev/null 2>&1; then
  echo "kubeconform is required but not installed or not on PATH." >&2
  exit 1
fi

# Validate only actual Kubernetes manifests. Descriptor files under argocd-apps/
# are consumed as templates and are intentionally not direct Kubernetes resources.
shopt -s globstar nullglob
manifests=(
  bootstrap/**/*.yml
  bootstrap/**/*.yaml
  categories/**/*.yml
  categories/**/*.yaml
  manifests/**/*.yml
  manifests/**/*.yaml
)
shopt -u globstar nullglob

if [ "${#manifests[@]}" -eq 0 ]; then
  echo "No manifest files found in bootstrap/, categories/, or manifests/." >&2
  exit 1
fi

kubeconform \
  -summary \
  -strict \
  -ignore-missing-schemas \
  -kubernetes-version 1.30.0 \
  "${manifests[@]}"
