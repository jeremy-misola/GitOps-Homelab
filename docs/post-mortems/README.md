# Post-Mortems

Incident retrospectives for the homelab cluster. Each document captures what
broke, why, how it was resolved, and the follow-up actions so the same failure
mode doesn't bite us twice.

These are written to be **blameless**: the goal is to improve the system and our
understanding of it, not to assign fault.

## Format

Each post-mortem follows the same structure:

- **Summary** — one paragraph: what happened and the impact.
- **Impact** — what was degraded, for how long, and who/what was affected.
- **Timeline** — key events with timestamps (UTC).
- **Root cause** — the actual mechanism, not just the symptom.
- **Resolution** — what was done to recover.
- **What went well / what went wrong** — honest assessment.
- **Action items** — concrete, owned follow-ups.
- **Lessons learned** — durable takeaways.

## Naming

`YYYY-MM-DD-short-slug.md`, e.g. `2026-06-24-crossplane-workspace-deletion-loop.md`.

## Index

| Date | Incident | Severity |
|------|----------|----------|
| 2026-06-24 | [Crossplane Workspace deletion loop](./2026-06-24-crossplane-workspace-deletion-loop.md) | High |
