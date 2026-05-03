#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <prod|dev>" >&2
  exit 1
fi

cluster="$1"
context="${cluster}-k3s"

case "$cluster" in
  prd|dev)
    ;;
  *)
    echo "Cluster must be 'prd' or 'dev'" >&2
    exit 1
    ;;
esac

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required to bootstrap a cluster" >&2
  exit 1
fi

if ! kubectl config get-contexts "$context" >/dev/null 2>&1; then
  echo "Kube context '$context' was not found. Provision the cluster first or merge kubeconfig locally." >&2
  exit 1
fi

kubectl --context "$context" apply -f "bootstrap/root-app-${cluster}.yaml"

echo "Bootstrap applied to $cluster using context $context"
