[**<---**](README.md)

# Devcontainer DX: sibling mounts without multi-root workspace

**Status:** decided and implemented (option **C**).

## Decision

Keep **sibling app clones** and the parent **`/workspaces`** bind so deploy can read **`/workspaces/<app>/.iac/`**. Do **not** require a multi-root **`*.code-workspace`** file or apps in the editor sidebar.

| Keep | Drop |
|------|------|
| Clone `iac` + apps as siblings on the host | Required `iac.code-workspace` |
| Devcontainer mounts parent → `/workspaces` | Multi-root sidebar ceremony |
| `task app:deploy -- <env> <app> <sha>` via `/workspaces/<app>` | Nesting apps under `iac/apps/` |

## How to open

1. Clone siblings (e.g. `~/projects/iac`, `~/projects/tientje-ketama`).
2. **File → Open Folder** on the **`iac`** directory (not a workspace file).
3. **Dev Containers: Reopen in Container**.

The sidebar shows the IaC repo only. App trees stay on disk at `/workspaces/<app>/` for tasks.

## Why not A (IaC-only, no parent mount)

Deploy needs `.iac/` inside the container. Removing the parent mount forces copy/optional binds/CI-only paths. C keeps deploy simple and only removes the editor ceremony that was unreliable.

## Related

- [Launch devcontainer](../launch-devcontainer.md)
- [Secrets and mounts](secrets-and-mounts.md)
