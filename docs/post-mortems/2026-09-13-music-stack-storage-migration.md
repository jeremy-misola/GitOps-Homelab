# Post-Mortem: Music Stack Storage Migration (prod-cp-3 → prod-worker-1)

| | |
|---|---|
| **Date** | 2026-09-13 |
| **Severity** | Medium |
| **Status** | Resolved |
| **Duration** | ~2h end-to-end (diagnosis → migration complete) |
| **Affected** | navidrome, filebrowser, lidarr, slskd, soularr (all storage-backed apps pinned to `prod-cp-3`) |

## Summary

`prod-cp-3` — a control-plane node with only ~5.8G memory and a 100G disk already
near its partition limit — was hosting the entire music stack (Navidrome,
Filebrowser, Lidarr, slskd, soularr) alongside a disproportionate share of the
cluster's core services (ArgoCD, cert-manager, Envoy Gateway, etc.), a side
effect of those services landing there during an earlier full-cluster reboot.
Under load, the container runtime on that node restarted, killing every pod on
it simultaneously and aborting in-flight Soulseek downloads mid-transfer. Since
`local-path` storage is node-local, the fix wasn't just "move the pods" — it
required physically migrating ~8.3G of PVC data (Navidrome's library/history,
Lidarr's database, and downloaded music) to `prod-worker-1`, a worker node with
~194G of disk and no etcd role.

## Impact

- All in-flight Soulseek downloads at the time of the container runtime restart
  were aborted (`"A task was canceled"`), requiring soularr to re-discover and
  re-grab them on its next cycles.
- The whole music stack (Navidrome, Filebrowser, Lidarr, slskd, soularr) was
  briefly unavailable during the migration window (pods intentionally scaled to
  0 to freeze source data before copying).
- No permanent data loss. Every volume was checksum-verified in a staging area
  on the destination node before the source PVCs were deleted.

## Timeline (UTC, approximate — same-day investigation and fix)

| Event |
|-------|
| User reports downloads appear "paused." Investigation finds `slskd` and other pods on `prod-cp-3` show `RESTARTS: 1`, all with the same timestamp, and `"Pod sandbox changed, it will be killed and re-created"` events — the container runtime restarted, not an app-level crash. |
| `free -h` on `prod-cp-3` shows only ~1.5G available out of 5.8G total, hosting 26 pods. No OOM record survived in `dmesg`'s ring buffer, but the timing correlates with additional debug/speed-test pods also scheduled there during unrelated diagnostics. |
| Decision made to migrate the whole music stack's storage to `prod-worker-1` (~194G disk, ~177G free, no etcd role) rather than just rebalancing pods, since `prod-cp-3`'s disk was also close to its ceiling. |
| `nodeSelector` updated via GitOps for navidrome, filebrowser, lidarr, slskd, and soularr (navidrome and slskd own PVCs directly; filebrowser/lidarr/soularr follow via `existingClaim`). Pushed and synced. |
| New pods go `Pending` (old node's PV affinity conflicts with the new `nodeSelector`) — old pods terminate cleanly, freezing the source data with zero risk of concurrent writes. |
| Backup pod created on `prod-cp-3` mounting all 6 original PVCs; each tarred and initially copied out via `kubectl cp` to the local operator machine. |
| `kubectl cp` repeatedly drops mid-transfer on large files (`websocket: close 1006`) — traced to the multi-hop path (operator machine → API server → kubelet → pod) riding a home network link measured at ~60–100 Mbps. |
| Switched strategy: direct **pod-to-pod transfer** over the cluster's internal network (`tar czf - \| nc <dest-pod-ip> <port>`), bypassing the operator's network link entirely. Backgrounded with `nohup` so transfers survive client-side disconnects. |
| Local backup copy of `navidrome-music` fills the operator machine's 7.8G tmpfs scratch disk, causing every subsequent shell command (even `echo`) to fail with `Disk quota exceeded` until the partial backup was deleted. |
| First pod-to-pod attempt (not yet backgrounded) is killed when its `kubectl exec` control connection drops — confirms even control-channel drops kill non-nohup'd remote processes. |
| Both large transfers (`navidrome-music` 5.7G, `slskd-downloads` 2.4G) and the 4 small config volumes complete via the pod-to-pod method and are checksum-verified against the originals. |
| The original backup pod's container hits its own `sleep 3600` timeout and exits naturally 70 minutes in, killing the (properly nohup'd, but still container-scoped) transfer processes mid-flight a second time — recreated with a 24h sleep and the two large transfers redone, this time sequentially. |
| Old PVCs deleted on `prod-cp-3` only after full checksum verification. New empty PVCs bind fresh on `prod-worker-1` via a temporary restore pod (forces `WaitForFirstConsumer` binding without waiting for the real app pods). |
| Staged data copied into the new real PVCs via a fast local same-node copy. Verification finds stray `.db-wal`/`.db-shm` files and a duplicate ASP.NET DataProtection key in two volumes — traced to a brief, accidental startup of the real app pods against the fresh empty PVCs before the deployments were fully scaled to 0. Stale journal files removed; 2 legitimately-new music files (grabbed during that same brief window) kept. |
| Deployments scaled back to 1. All 5 pods come up `1/1 Running` on `prod-worker-1` with correct data (144 tracks in Navidrome, 4 artists in Lidarr, matching file counts throughout). Migration scaffolding (temp pods/PVCs) cleaned up. `git status` clean, all ArgoCD apps `Synced`/`Healthy`. |

## Root cause

**Immediate cause of the outage:** `prod-cp-3` was overcommitted on both memory
and disk. It carried 26 pods — a mix of the pinned music stack and a
disproportionate share of cluster-core services that had landed there during an
earlier full-cluster reboot and never got rebalanced — against only 5.8G of
memory and a 100G disk that was already ~24% consumed with no room to grow the
partition further. Under load, the container runtime restarted, and because
Kubernetes has no notion of "gracefully pause an in-flight P2P transfer," every
active Soulseek download died with it.

**Why storage migration was necessary, not just a pod reschedule:** `local-path`
provisions storage directly on a node's local disk with a hard `nodeAffinity` to
that node baked into the PV. Changing a `nodeSelector` alone only makes pods
*want* to move — the data has to physically follow, since no other node can see
it.

**Contributing factors that turned a straightforward copy into several
iterations:**
1. `kubectl cp`/`kubectl exec` route data (and control signals) through the
   operator's own network link. A slow, occasionally-unstable link makes this
   both slow and prone to killing transfers outright when the *control*
   connection drops — not just when the data connection does.
2. Backing up large volumes to the operator machine's own temp disk assumed
   capacity that didn't exist (a 7.8G tmpfs against ~8.3G of data), and silently
   broke basic shell operation once exhausted rather than failing loudly.
3. `nohup` on a background process only protects against `SIGHUP` from a
   disconnected *shell* — it does not survive the *container itself* exiting
   (e.g., a `sleep N` main process reaching its timeout), which was easy to
   under-provision for an operation that ran longer than first estimated.
4. Scaling a Deployment to 0 replicas doesn't stick under ArgoCD's `selfHeal`
   unless the desired replica count is actually 0 in the source of truth (it
   isn't, here) — the real mechanism that froze writes safely was the
   `nodeSelector`/PV-affinity conflict putting pods in `Pending`, not the manual
   `kubectl scale`.

## Resolution

1. Updated `nodeSelector: kubernetes.io/hostname` from `prod-cp-3` to
   `prod-worker-1` for navidrome, filebrowser, lidarr, slskd, and soularr in
   Git, letting the scheduling conflict itself freeze the source data safely.
2. Transferred all 6 PVCs' data pod-to-pod over the cluster's internal network
   (`tar | nc`, backgrounded with `nohup` and a generous container lifetime)
   into a staging PVC on the destination node, entirely bypassing the slow
   operator-to-cluster link.
3. Verified every volume byte-for-byte (file counts + checksums) before
   touching the originals.
4. Deleted the old PVCs, let fresh empty ones bind on `prod-worker-1`, copied
   the staged data in with a fast local same-node copy, cleaned up two files'
   worth of stale SQLite WAL/journal artifacts left by a brief accidental app
   startup against the empty volumes, and scaled the real deployments back up.

## What went well

- Verifying every volume with file-count + checksum comparisons before any
  destructive step caught a real, if minor, risk (stale WAL files paired with a
  swapped-out database generation) before it could cause a startup-time
  corruption issue.
- Pivoting to a pod-to-pod transfer once `kubectl cp` proved unreliable was the
  right call — once implemented, both multi-gigabyte transfers completed
  cleanly and quickly, entirely decoupled from the operator's local network
  conditions.
- No data was lost at any point; the original PVCs were never deleted until
  their replacement was fully verified.

## What went wrong

- Two separate self-inflicted stalls (disk quota exhaustion on the operator's
  own scratch disk, and a background transfer dying with its container's
  `sleep` timeout) cost real time and could have been avoided by sizing the
  transfer plan around the operator environment's actual constraints up front.
- The root cause (`prod-cp-3` overcommitted on memory/disk) was diagnosed
  reactively, from a user-visible symptom ("downloads are paused"), rather than
  from any proactive resource alerting.
- No mechanism currently rebalances pods across nodes after a full-cluster
  reboot, which is how `prod-cp-3` ended up disproportionately loaded in the
  first place.

## Action items

- [ ] Consider setting resource `requests`/`limits` on `prod-cp-3`-pinned
      workloads, or a taint discouraging non-essential scheduling there, so a
      future full-cluster reboot doesn't repeat the overcommit.
- [ ] Add basic node-level alerting (memory/disk headroom) so this class of
      problem surfaces before a user notices cancelled downloads.
- [ ] For any future cross-node `local-path` migration, default to the
      pod-to-pod (`tar | nc`) transfer method from the start rather than
      `kubectl cp`, and size any local scratch usage against the actual
      environment's disk/tmpfs limits first.
- [ ] Document (here or in the repo's operational notes) that scaling a
      Deployment to 0 is not reliable under ArgoCD `selfHeal` unless replica
      count is git-managed — a scheduling constraint (`nodeSelector` vs. PV
      affinity) is a more dependable way to freeze a workload mid-migration.

## Lessons learned

1. **`local-path` migrations are data migrations, not scheduling changes.**
   A `nodeSelector` update alone only makes pods *want* to move; the actual
   bytes have to be moved by hand, deliberately, before the new node's PVC can
   be anything but empty.
2. **A network path an operator doesn't control shouldn't be load-bearing for a
   migration.** Routing gigabytes of data through `kubectl cp`/`kubectl exec` on
   a slow or unstable link turns transient hiccups into hard failures. Cluster-
   internal pod-to-pod transfer avoids the problem entirely.
3. **`nohup` protects against a dropped shell, not a dying container.** Any
   long-running background task inside a throwaway pod needs a lifetime
   (`sleep N`, or better, no arbitrary timeout at all) sized generously against
   realistic worst-case duration, not the happy path.
4. **Verify before you delete.** Checksumming every volume in a staging area
   before removing the originals turned what could have been a silent data-
   corruption bug (mismatched WAL files) into a two-line cleanup instead.
