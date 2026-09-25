[**<---**](../rules/project.mdc)

# Public repo vs secrets

Public `iac` template without secrets; ciphertext in a **private sibling**; **full rotate** (one three-list per provider); then **replace public git history** (orphan root) as the **last** step.

---

## Decided

| | |
|--|--|
| Prior model | SOPS ciphertext in public git was **intentional**; secrets also lived under other paths earlier. |
| Custody | **Public `rednaw/iac`**, no secrets in that tree. Encrypted secrets in a **private sibling** (`../secrets` from the iac root; override with `SECRETS_DIR`). |
| Rotate | **Full rotate** of values that lived in public blobs; new ciphertext only in the sibling; revoke old tokens. **Each provider is its own three-list** under `plans/rotate/` or `completed/rotate/`. |
| History timing | Rewrite public history **last**, after every rotate is done or out of scope. Rotates are done. |
| Why last | Dropping history does not unsay old clones; rotate first so surviving archives hold obsolete values. |
| Secret paths in history | SOPS ciphertext only in `secrets/infrastructure-secrets.yml.enc` → `secrets/infrastructure-secrets.yml` → `secrets/infra.yml`. Also under `secrets/`: `.sops.yaml` and `sops-key-*.pub` (public, not secret). No plaintext private keys in any blob. `app/secrets.yml` was always empty |
| Renames | A path-based purge handles renames, because it filters every commit's tree by path. It only needs the complete list of historical paths: the whole `secrets/` directory |
| GitHub PR refs | 374 `refs/pull/*` on origin keep old commits reachable. They are read-only: a force-push does not remove them. Only deleting and recreating the repo, or GitHub Support, clears them (and cached commit views) |
| Repo facts | 531 commits, 37 remote branches, tag `v1.0.0`, pack ~241 KiB |
| Operator sequence (per rotate) | Edit sibling → push **secrets** → reload setup if hcloud/TFC/docker auth → smoke (`provision:plan` and/or `configure:apply` as that plan says) → revoke old. |
| Usually keep | `base_domain`, `app_domain`, `terraform_cloud_organization`, `ssh_keys`, `allowed_ssh_ips`, `cms_oauth_allowed_domains`, `server_type`, `github_oauth_hostname`, `vpn_dest`, `vpn_allowed_ssh_ips` (optional hygiene only). |
| App `.iac/.env` | Never in public `iac` history for this migration — rotate only if published elsewhere. |

## Decide

### How to rewrite history?

Both rewrites give every commit a new SHA, so any old clone diverges.

| | Option |
|--|--------|
| **A** | **Orphan root.** One new commit holding today's tree. All history is gone; nothing to get wrong. |
| **B** | **Path purge** (`git filter-repo --invert-paths --path secrets/`). Keeps all 531 commits minus the `secrets/` files. Blame and log stay useful. PR numbers in commit messages point at stale PRs |

Choice: _unpicked_

### What happens to GitHub's copies (PR refs, cached commits)?

| | Option |
|--|--------|
| **A** | **Delete and recreate** `rednaw/iac`, then push the rewritten history. Clears PR refs and caches. Loses PRs, issues, stars, Actions history, and repo settings. Redo: `RENOVATE_TOKEN` secret, branch protection, GHCR package links (`iac-dev` etc.). `tientje-ketama` calls `_build-and-push.yml@main` by name, so it keeps working |
| **B** | **Keep the repo**, force-push, then ask GitHub Support to purge cached views and PR refs. Keeps PRs and issues, but they are unreliable until Support acts |
| **C** | **Keep the repo**, force-push only. Old commits stay reachable via `refs/pull/*` for anyone who knows how to look |

Choice: _unpicked_

## Do

Checkboxes track status only. The agent may change only **Agent** boxes; only the human may change **Human** boxes.

### 0. Private sibling

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — after the human supplies the chosen sibling path: update `task secrets:*`, the devcontainer and every runtime reference so `iac` reads encrypted secrets from the private sibling; add checks that fail clearly when it is missing.

**Human must:** Create a private GitHub repository for the secrets, clone it beside `iac`, copy the current `secrets/` tree into it without decrypting files, and tell the agent its repository name and local path. Keep it private; do not commit or push the public-tree removal yet.

**Done as:** sibling `rednaw/secrets` (`../secrets`). Runtime resolves `SECRETS_DIR=$(realpath -m <iac>/../secrets)` (override with env). Public `iac/secrets/` still present until Do 1. Copied missing `.sops.yaml` (dotfiles not matched by `cp secrets/*`).

### 1. Clean public tip

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — after 0: ignore secret paths in public `iac`, remove tracked secret files from its working tree, update templates/setup for the sibling, and verify platform/VPN commands resolve the sibling. Do **not** rewrite history.

**Human must:** Review the deletion and path changes, confirm the private sibling decrypts first, then commit and push the clean public tip normally. Do not orphan or force-push yet.

**Done as:** `git rm` of tracked `secrets/*`; `.gitignore` keeps ignoring `secrets/` as a safety net (sibling is `../secrets`). Platform TF secrets script decrypts sibling. No history rewrite.

### 2. Full rotate (per-provider plans)

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — inventory + one three-list per provider; sibling wiring already refreshes hcloud + `TF_TOKEN` from `../secrets`.

**Human must:** Drive each open rotate plan to both boxes checked (or explicit out-of-scope). Never paste plaintext into chat or the public repo.

**Done as (Agent):** Index below. All rotate rows done or out of scope; **Do 3** (orphan history) is unblocked.

| Provider | Plan | Status |
|--|--|--|
| Hetzner Cloud | [completed/rotate/hetzner.md](../completed/rotate/hetzner.md) | done |
| Terraform Cloud | [completed/rotate/terraform-cloud.md](../completed/rotate/terraform-cloud.md) | done |
| TransIP | [completed/rotate/transip.md](../completed/rotate/transip.md) | done |
| Platform registry | [completed/rotate/registry.md](../completed/rotate/registry.md) | done |
| OpenObserve | [completed/rotate/openobserve.md](../completed/rotate/openobserve.md) | done |
| AbuseIPDB | [completed/abuseipdb.md](../completed/abuseipdb.md) | done (outage fix; not a rotate-first plan) |
| GitHub OAuth | [completed/rotate/github-oauth.md](../completed/rotate/github-oauth.md) | done |
| VPN | — | out of scope (VPN not provisioned yet; no rotate) |

### 3. Replace public history (last)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after both Decide items: in a fresh `--mirror` clone under `/tmp` (never the working repo), build the rewritten history (orphan or `filter-repo`), then re-run the blob scan to show zero SOPS blobs across all refs. Prepare the exact push/ref-delete commands. Agent will not push, delete remote refs, or touch GitHub settings.

**Human must:** Optionally push the untouched mirror to a private `iac-legacy` first. Then run the prepared push (and repo recreate or Support request, per the pick). Re-clone `iac` locally afterwards; old clones must not be pushed back. Assume third-party clones remain forever.

### 4. Docs

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — can start now: update existing operator documentation and setup text to describe public `iac` plus a private secrets sibling; remove fork, `git add -f` and “ciphertext in public git” as the default workflow.

**Human must:** Review the documented clone/bootstrap workflow from the perspective of a fresh machine and confirm the private repository remains undiscoverable to public users.

**Done as:** README bootstrap = clone `iac` + private `secrets` sibling; help text + future docs + Ansible fail messages point at `../secrets`. No `git add -f secrets/` workflow.

### 5. Verify

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 3: read-only local/remote history and path scans; verify public `main` is a single clean root, no origin ref reaches the old graph, sibling decrypts, platform/VPN commands resolve it.

**Human must:** Inspect GitHub signed out; run platform and VPN smokes with new credentials; accept the migration.
