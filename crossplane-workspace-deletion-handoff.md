# Crossplane Terraform Workspace Deletion Issue — Handoff

## Symptom

Any `tf.upbound.io/Workspace` resource managed by a prereqs ArgoCD Application (e.g. `adguard-prereqs`, `mimir-prereqs`) is deleted within ~30 seconds of being created. The Crossplane events show:

1. `CreatedExternalResource` — Terraform apply started
2. `DeletedExternalResource` — Terraform destroy triggered ~15–30s later

The resource never reaches `Ready: True`. A new one gets created, and the cycle repeats indefinitely.

## Cluster Context

- ArgoCD v3.3.9
- Crossplane with `provider-terraform` (tf.upbound.io)
- App-of-Apps pattern: a `root` Application manages all child Applications
- All prereqs Applications have `selfHeal: true`, `prune: true`, `ServerSideApply=true`

## What Was Investigated

### ArgoCD Application config (`adguard-prereqs`, `mimir-prereqs`)

Both Applications have:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - ServerSideApply=true
```

### Timeline of a typical deletion (from resource events/timestamps)

| Time | Event |
|------|-------|
| T+0s | ArgoCD creates Workspace (sync) |
| T+7s | Crossplane starts Terraform apply (`external-create-pending`) |
| T+18–30s | `deletionTimestamp` set — someone deletes the K8s resource |
| T+21s | Terraform apply finishes (`external-create-succeeded`) |
| T+21s | Crossplane sees `deletionTimestamp`, runs `terraform destroy` |

### ArgoCD logs (app controller)

The logs showed ArgoCD repeatedly re-creating the Workspace with `nil->obj` (resource doesn't exist → create it), with `SelfHealAttemptsCount` climbing to 6+. The Application status shows the Workspace as `OutOfSync` immediately after each creation.

The suspected cause: **Crossplane mutates the Workspace after ArgoCD creates it** — adding annotations (`crossplane.io/external-name`, `crossplane.io/external-create-pending`, `crossplane.io/external-create-succeeded`) and a finalizer (`finalizer.managedresource.crossplane.io`). ArgoCD sees these as drift, `selfHeal` triggers, and something in the repeated cycle causes the Workspace to be deleted.

### Fixes attempted (neither worked)

1. **`argocd-cm` `ignoreDifferences`** — Added `resource.customizations.ignoreDifferences.tf.upbound.io_Workspace` to tell ArgoCD to ignore Crossplane-managed annotations and finalizers. The Workspace was still deleted. **Reverted.**

2. **`argocd.argoproj.io/compare-options: IgnoreExtraneous`** annotation on all 13 Workspace templates — Tells ArgoCD to ignore extra fields in the live resource. Still deleted. **Reverted.**

### Secondary issue found

`garage-loki-buckets` (namespace: `crossplane-system`) has been stuck in `Terminating` for 23 days — the Crossplane finalizer is blocking deletion while `terraform destroy` is presumably stuck or failing. This is blocking the `root` Application at sync wave 29:

```
waiting for healthy state of argoproj.io/Application/loki-prereqs
```

This cascades and prevents all wave 30+ Applications from syncing in the root sync.

## What's Still Unknown

The exact mechanism that issues the `kubectl delete` on the Workspace is not confirmed. The two most likely remaining candidates:

1. **ArgoCD partial sync with prune** — On a selfHeal re-sync, ArgoCD may be computing an empty desired state for the Workspace (e.g. Helm render returning nothing due to a values or template issue at the time of comparison), then pruning the live resource. This would need to be caught by comparing the exact Helm render ArgoCD uses at the moment of the self-heal vs the template on disk.

2. **Something else in the cluster** — A controller or admission webhook that reacts to Workspace state and issues a delete. Worth checking if any Kyverno policies or other controllers are watching `tf.upbound.io` resources.

## Recommended Next Steps

1. **Catch the delete in the act** — Enable ArgoCD audit logging or watch the Kubernetes API audit log to see exactly which actor (user/serviceaccount) sets the `deletionTimestamp`. This will definitively identify the source.

   ```bash
   # Watch for deletionTimestamp being set on any Workspace
   kubectl get workspace -w -A
   ```

2. **Check Kyverno policies** — Search for any ClusterPolicy or Policy that targets `tf.upbound.io` resources:

   ```bash
   kubectl get clusterpolicy,policy -A -o yaml | grep -i "tf.upbound\|Workspace"
   ```

3. **Unblock `garage-loki-buckets`** — Force-remove the Crossplane finalizer to unstick the root sync:

   ```bash
   kubectl patch workspace garage-loki-buckets -n crossplane-system \
     --type=json \
     -p='[{"op":"remove","path":"/metadata/finalizers"}]'
   ```
   *(Note: the namespace may be `crossplane-system` based on the Git manifest, not `loki` as the ArgoCD destination suggests — this was not confirmed.)*

4. **Re-examine Helm render** — Run `helm template` locally for one of the failing pre-resources charts and compare it against what ArgoCD is computing during a self-heal. A mismatch (empty render) would explain the prune.

## Files Changed During Investigation

All changes were reverted. Current state of the repo is identical to before this session.
