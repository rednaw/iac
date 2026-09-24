[**<---**](../rules/project.mdc)

# Public repo vs secrets

Public `iac` template without secrets; ciphertext in a **private sibling**; **full rotate**; then **replace public git history** (orphan root) as the **last** step.

---

## Decided

| | |
|--|--|
| Prior model | SOPS ciphertext in public git was **intentional**; secrets also lived under other paths earlier. |
| Custody | **Public `rednaw/iac`**, no secrets in that tree. Encrypted secrets in a **private sibling** (`../secrets` from the iac root; override with `SECRETS_DIR`). |
| Rotate | **Full rotate** of values that lived in public blobs; new ciphertext only in the sibling; revoke old tokens. |
| History | **Orphan / replace public history** (single new root = tree without secrets; force-push `main`; delete or reset stale remote branches/tags). **Last step — only after rotate is done.** |
| Why last | Dropping history does not unsay old clones; rotate first so surviving archives hold obsolete values. Then public `main` has no secret parents. |
| Repo facts | ~389 commits, ~90 branch refs, tag `v1.0.0`, `.git` ~22M — small enough for orphan replace. |

## Decide

None.

## Do

Checkboxes track status only. The agent may change only **Agent** boxes; only the human may change **Human** boxes. Task bodies assign the work.

### 0. Private sibling

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — after the human supplies the chosen sibling path: update `task secrets:*`, the devcontainer and every runtime reference so `iac` reads encrypted secrets from the private sibling; add checks that fail clearly when it is missing.

**Human must:** Create a private GitHub repository for the secrets, clone it beside `iac`, copy the current `secrets/` tree into it without decrypting files, and tell the agent its repository name and local path. Keep it private; do not commit or push the public-tree removal yet.

**Done as:** sibling `rednaw/secrets` (`../secrets`). Runtime resolves `SECRETS_DIR=$(realpath -m <iac>/../secrets)` (override with env). Public `iac/secrets/` still present until Do 1. Copied missing `.sops.yaml` (dotfiles not matched by `cp secrets/*`).

### 1. Clean public tip

- [x] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 0: ignore secret paths in public `iac`, remove tracked secret files from its working tree, update templates/setup for the sibling, and verify platform/VPN commands resolve the sibling. Do **not** rewrite history.

**Human must:** Review the deletion and path changes, confirm the private sibling decrypts first, then commit and push the clean public tip normally. Do not orphan or force-push yet.

**Done as:** `git rm` of tracked `secrets/*`; `.gitignore` keeps ignoring `secrets/` as a safety net (sibling is `../secrets`). Platform TF secrets script decrypts sibling. No history rewrite.

### 2. Full rotate

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 0: inventory every secret key consumed by Terraform, Ansible, tasks, apps and VPN; produce a provider-by-provider rotation checklist; update non-secret wiring and validate that setup refreshes `TF_TOKEN` and hcloud credentials from the sibling.

**Human must:** In each provider console, mint replacements for every exposed value (Hetzner, TFC, TransIP, registry, GitHub OAuth and VPN UUID/REALITY/short ID when present), store only the replacements in the encrypted sibling, test them, then revoke the old values. Never paste plaintext values into chat or the public repo.

### 3. Replace public history (last)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 2: inspect all local and remote refs, prepare the exact orphan-root/ref-cleanup commands, and verify the candidate root contains no secret paths. The agent will not commit, force-push or delete remote refs.

**Human must:** Only after every old credential is revoked, create the orphan root and force-push `main`; delete or recreate every stale remote branch/tag that reaches the old graph, including `v1.0.0`. Optionally preserve the old history in a private `iac-legacy` archive; assume third-party clones remain forever.

### 4. Docs

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now: update existing operator documentation and setup text to describe public `iac` plus a private secrets sibling; remove fork, `git add -f` and “ciphertext in public git” as the default workflow.

**Human must:** Review the documented clone/bootstrap workflow from the perspective of a fresh machine and confirm the private repository remains undiscoverable to public users.

### 5. Verify

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 3: perform read-only local/remote history and path scans; verify public `main` is a single clean root (or intended shallow history), no remaining origin ref reaches the old graph, the sibling decrypts, and platform/VPN commands resolve it.

**Human must:** Inspect GitHub while signed out to confirm no secret files or old refs are public, run the platform and VPN smoke commands with the new credentials, and accept the migration.
