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
| History | **Orphan / replace public history** (single new root = tree without secrets; force-push `main`; delete or reset stale remote branches/tags). **Last step — only after every rotate plan is done (or explicitly out of scope).** |
| Why last | Dropping history does not unsay old clones; rotate first so surviving archives hold obsolete values. Then public `main` has no secret parents. |
| Repo facts | ~389 commits, ~90 branch refs, tag `v1.0.0`, `.git` ~22M — small enough for orphan replace. |
| Operator sequence (per rotate) | Edit sibling → push **secrets** → reload setup if hcloud/TFC/docker auth → smoke (`provision:plan` and/or `configure:apply` as that plan says) → revoke old. |
| Usually keep | `base_domain`, `app_domain`, `terraform_cloud_organization`, `ssh_keys`, `allowed_ssh_ips`, `cms_oauth_allowed_domains`, `server_type`, `github_oauth_hostname`, `vpn_dest`, `vpn_allowed_ssh_ips` (optional hygiene only). |
| App `.iac/.env` | Never in public `iac` history for this migration — rotate only if published elsewhere. |

## Decide

None.

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
- [ ] Human: reviewed

**Agent will implement** — inventory + one three-list per provider; sibling wiring already refreshes hcloud + `TF_TOKEN` from `../secrets`.

**Human must:** Drive each open rotate plan to both boxes checked (or explicit out-of-scope). Never paste plaintext into chat or the public repo.

**Done as (Agent):** Index below. Wiring + inventory split out of the checklist.

| Provider | Plan | Status |
|--|--|--|
| Hetzner Cloud | [completed/rotate/hetzner.md](../completed/rotate/hetzner.md) | done |
| Terraform Cloud | [completed/rotate/terraform-cloud.md](../completed/rotate/terraform-cloud.md) | done |
| TransIP | [rotate/transip.md](rotate/transip.md) | open |
| Platform registry | [rotate/registry.md](rotate/registry.md) | open |
| OpenObserve | [rotate/openobserve.md](rotate/openobserve.md) | open |
| AbuseIPDB | [rotate/abuseipdb.md](rotate/abuseipdb.md) | open (key minted; fail2ban blocked) |
| GitHub OAuth | [rotate/github-oauth.md](rotate/github-oauth.md) | open |
| VPN | [rotate/vpn.md](rotate/vpn.md) | open |

### 3. Replace public history (last)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after every rotate plan is done or out of scope: inspect refs, prepare orphan-root/ref-cleanup commands, verify candidate root has no secret paths. Agent will not commit, force-push, or delete remote refs.

**Human must:** Only after every old credential is revoked (or N/A), create the orphan root and force-push `main`; delete or recreate every stale remote branch/tag that reaches the old graph, including `v1.0.0`. Optionally preserve old history in a private `iac-legacy` archive; assume third-party clones remain forever.

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
