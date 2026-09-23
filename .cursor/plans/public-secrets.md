[**<---**](../rules/project.mdc)

# Public repo vs secrets

Public `iac` template without secrets; ciphertext in a **private sibling**; **full rotate**; then **replace public git history** (orphan root) as the **last** step.

---

## Decided

| | |
|--|--|
| Prior model | SOPS ciphertext in public git was **intentional**; secrets also lived under other paths earlier. |
| Custody | **Public `rednaw/iac`**, no secrets in that tree. Encrypted secrets in a **private sibling repo**. |
| Rotate | **Full rotate** of values that lived in public blobs; new ciphertext only in the sibling; revoke old tokens. |
| History | **Orphan / replace public history** (single new root = tree without secrets; force-push `main`; delete or reset stale remote branches/tags). **Last step — only after rotate is done.** |
| Why last | Dropping history does not unsay old clones; rotate first so surviving archives hold obsolete values. Then public `main` has no secret parents. |
| Repo facts | ~389 commits, ~90 branch refs, tag `v1.0.0`, `.git` ~22M — small enough for orphan replace. |

## Decide

None.

## Do

### 0. Private sibling

can start now — Create private GitHub repo (e.g. `rednaw/iac-secrets`). Seed from current `secrets/`. Document path (e.g. `../iac-secrets`). Point `task secrets:*` / devcontainer at sibling if they hardcode `iac/secrets/`.

### 1. Clean public tip

can start now — Gitignore secrets paths; `git rm` tracked `secrets/` from `iac` tip; commit; push. Runtime reads sibling. **Do not** orphan/force-push history yet.

### 2. Full rotate

after 0 (sibling can hold new ciphertext) — Inventory keys; mint new Hetzner, TFC, TransIP, registry, OAuth, VPN UUID/REALITY/short_id if present, etc.; write only to sibling; revoke old tokens in consoles; refresh `TF_TOKEN` / hcloud via setup (bashrc overwrite).

### 3. Replace public history (last)

after 2 — Orphan root from current tip (no secrets); force-push `main`; delete or recreate stale `origin` branches/tags that still point at the old graph (including `v1.0.0` or move it); assume prior clones may remain. Optional: keep a **private** `iac-legacy` archive of the old history for yourself only.

### 4. Docs

can start now — Public template + private sibling; no fork/`git add -f` / “SOPS-in-this-public-repo” as the ops default.

### 5. Verify

after 3 — Public `main` is a single root (or shallow history) with no secret paths; `git log --all` on origin doesn’t reintroduce old graph via leftover branches; sibling decrypts; platform/vpn tasks work.
