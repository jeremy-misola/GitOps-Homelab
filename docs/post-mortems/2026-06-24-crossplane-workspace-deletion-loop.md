# Post-Mortem: Crossplane Terraform Workspace Deletion Loop

| | |
|---|---|
| **Date** | 2026-06-24 |
| **Severity** | High |
| **Status** | Resolved |
| **Duration** | ~2h (CRD wedged 21:01 UTC → resolved ~23:09 UTC) |
| **Affected** | All `tf.upbound.io/Workspace` resources (Authentik OIDC apps + Garage bucket provisioning); cascaded to block the App-of-Apps root sync at wave 29+ |

## Summary

During a Crossplane v2 migration, the `workspaces.tf.upbound.io` CRD became stuck
in a `Terminating` state. While a CRD is terminating, the Kubernetes apiextensions
cleanup controller deletes every instance of that kind within seconds of creation.
This produced a relentless create → delete loop on every `Workspace`: ArgoCD's
`selfHeal` recreated them, and Kubernetes reaped them ~30s later. The loop could
not clear because one Workspace — `garage-loki-buckets` — held a Crossplane
finalizer and its `terraform destroy` was permanently failing, which kept the CRD
from ever finishing deletion. The fix was to let that Workspace orphan its external
resource instead of destroying it, which unblocked CRD cleanup, allowed a fresh CRD
to be re-established, and let the Workspaces stick.

## Impact

- No Authentik OIDC providers/applications could be provisioned — every `*-auth`
  Workspace (adguard, code-server, homepage, vaultwarden, stirling-pdf, grafana,
  immich, headlamp, backstage/devdocs, etc.) was created and destroyed in a loop,
  never reaching `Ready`.
- Loki S3 bucket provisioning (`garage-loki-buckets`) was stuck `Terminating` for
  ~23 days of wall-clock resource age and actively failing its delete.
- The App-of-Apps `root` Application was blocked at sync wave 29 waiting on
  `loki-prereqs` to reach a healthy state, cascading to stall all wave 30+
  Applications.
- No data loss. The external Garage buckets were never actually deleted (the
  destroy was failing), so they survived intact.

## Timeline (UTC)

| Time | Event |
|------|-------|
| ~20:19–22:16 | Crossplane v2 components installed/upgraded — new `*.m.crossplane.io` CRDs, `ManagedResourceDefinition` (MRD), `ManagedResourceActivationPolicy` (MRAP), `ops`/`protection` CRDs all created. |
| 21:01:45 | The original `workspaces.tf.upbound.io` CRD (created 2026-05-31) receives a `deletionTimestamp` as part of the migration to MRD-managed CRDs. It enters `Terminating` and cannot complete because `garage-loki-buckets` holds the `finalizer.managedresource.crossplane.io` finalizer with a failing `terraform destroy`. |
| 21:01–23:09 | Every `Workspace` created by ArgoCD is reaped by the CRD cleanup controller within ~30s (grace period 0). `selfHeal` recreates them; they are reaped again. Loop runs indefinitely. |
| 22:15:00 | New MRD `workspaces.tf.upbound.io` is created and reconciles to `Active`/`Established`; MRAP `default` (`activate: ["*"]`) lists it as activated. The new machinery is correct but cannot re-establish a clean CRD while the old one is wedged. |
| ~23:09:07 | Mitigation: `garage-loki-buckets` patched to `deletionPolicy: Orphan` and `managementPolicies` reduced to exclude `Delete`. |
| ~23:09:16 | Crossplane skips the failing destroy, removes its finalizer; the old stuck Workspace is deleted. |
| ~23:09:35 | Old CRD finishes terminating; the Active MRD immediately re-establishes a fresh `workspaces.tf.upbound.io` CRD (new uid, no `Terminating` condition). |
| ~23:10 | ArgoCD `selfHeal` repopulates Workspaces onto the healthy CRD. `garage-loki-buckets` returns `SYNCED: True` with real Terraform outputs; `*-auth` Workspaces persist past 30s and begin reconciling normally. Loop resolved. |

## Root cause

**A terminating CRD reaps its own custom resources.** The trigger was the
Crossplane v2 migration, which moved provider CRDs under the
`ManagedResourceDefinition` lifecycle and, in the process, marked the
pre-existing `workspaces.tf.upbound.io` CRD for deletion. A CRD with a
`deletionTimestamp` causes Kubernetes to garbage-collect all of its instances —
so every `Workspace` was deleted within seconds of being (re)created.

**The CRD could not finish terminating.** A CRD's
`customresourcecleanup.apiextensions.k8s.io` finalizer only clears once all
instances are gone. `garage-loki-buckets` blocked this: it held the Crossplane
managed-resource finalizer, and its `terraform destroy` failed every time with
`failed to delete bucket: 409 Conflict`. One un-deletable Workspace held the
entire CRD — and therefore every Workspace — hostage.

**Why the earlier fixes failed.** The prior investigation assumed ArgoCD was
deleting the Workspaces (via `prune` / `selfHeal` drift). It was not. The deleter
was the Kubernetes CRD cleanup controller. That's why `ignoreDifferences` and
`compare-options: IgnoreExtraneous` had no effect — they targeted the wrong actor.
The perpetual `OutOfSync` and climbing `SelfHealAttemptsCount` were real, but they
were a *symptom* of the resource being deleted out from under ArgoCD, not the cause.

## Resolution

`garage-loki-buckets` was reconfigured so Crossplane would stop trying to run the
failing destroy:

```yaml
spec:
  deletionPolicy: Orphan
  managementPolicies:        # Delete removed
    - Observe
    - Create
    - Update
    - LateInitialize
```

With `Delete` off the table, Crossplane removed its finalizer without attempting
the external `terraform destroy`. The blocking Workspace was deleted, the old CRD
drained to zero instances and finished terminating, and the still-`Active` MRD
re-established a fresh CRD. ArgoCD then recreated all Workspaces onto the healthy
CRD and they stuck. The Garage buckets were orphaned (not deleted) and were
re-adopted by the recreated Workspace, which returned `Ready`.

## What went well

- The new Crossplane v2 plumbing (MRD `Active`/`Established`, MRAP activating `*`,
  provider-terraform `Healthy`) was already correct, so recovery only required
  unblocking the old CRD rather than rebuilding anything.
- Choosing `Orphan` over force-removing the finalizer meant the external Garage
  buckets were preserved and cleanly re-adopted — no data loss, no manual bucket
  recreation.

## What went wrong

- The failure mode was misdiagnosed for an extended period as an ArgoCD
  prune/selfHeal problem, leading to several ineffective ArgoCD-side fixes.
- A single resource with a failing `terraform destroy` was able to wedge a
  cluster-wide CRD lifecycle operation, with no alerting on either the stuck CRD
  or the 23-day `Terminating` Workspace.
- The migration that re-marked the CRD for deletion happened without noticing that
  a Workspace with a broken destroy would deadlock it.

## Action items

- [ ] **Decide the durable config for `garage-loki-buckets`.** The live object now
      has `deletionPolicy: Orphan` + reduced `managementPolicies`, which is *not* in
      Git (`operators-helm/operators/loki/pre-resources/garage-loki-buckets.yaml`).
      Either bake this into the template (protective against repeat deadlocks) or
      revert to default `Delete` once bucket reconciliation is confirmed stable.
- [ ] **Fix the underlying `409 Conflict` on Garage bucket delete** so a real
      destroy can succeed if/when intended (likely non-empty bucket or alias/website
      config blocking deletion).
- [ ] **Add monitoring/alerting** for (a) any CRD stuck in `Terminating` and
      (b) any managed resource stuck `Terminating` beyond a threshold (e.g. >1h).
- [ ] **Consider `deletionPolicy: Orphan` (or `managementPolicies` without
      `Delete`) as the default** for Workspaces whose external resources are
      data-bearing (object-store buckets), so a failing destroy can never wedge the
      CRD again.
- [ ] **Remove the now-misleading ArgoCD workarounds** if they were left in place,
      and document that the `compare-options: IgnoreExtraneous` annotation was not
      the fix.
- [ ] **Update / retire** `crossplane-workspace-deletion-handoff.md`, whose
      root-cause section is now superseded by this post-mortem.

## Lessons learned

1. **A `Terminating` CRD deletes its own CRs.** If managed resources are being
   created and destroyed in a tight loop, check the *CRD's* `deletionTimestamp`
   and conditions before suspecting the GitOps controller.
2. **Identify the actor before applying fixes.** "Something is deleting X" should
   be answered with the real deleter (owner refs, finalizers, controller logs, the
   CRD's own state) before reaching for controller-level workarounds.
3. **A single failing `terraform destroy` is a cluster-wide hazard.** Crossplane's
   finalizer + a failing external delete can block CRD lifecycle for *every*
   resource of that kind. Data-bearing resources should favor `Orphan`.
4. **CRD migrations need a pre-flight check** that no instance is stuck deleting,
   or the migration can deadlock on the way through.
