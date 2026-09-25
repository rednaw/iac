# GitHub CLI auth in the iac Dev Container

`gh` is installed (`mise` `github-cli`) but never authenticated. Sibling setup already wires hcloud, TFC, and Docker registry — not `gh`. Git push via `git@github.com` stays on the host `~/.ssh` bind.

## Decided

| | |
|--|--|
| Today | `gh` binary present; not logged in. Auth was never implemented (not a regression). |
| Git ≠ gh | `~/.ssh` for `git@`; `gh` API needs token auth. |
| Scope | **iac** Dev Container first. |
| Credential path | **1B** — PAT (or fine-grained token) in `../secrets/infra.yml`; `devcontainer-setup.sh` materializes auth in the container (same family as hcloud/TFC/registry: regenerate on setup, not a host `~/.config/gh` bind). |
| Materialize | Prefer `gh auth login --with-token` → `~/.config/gh/…` (durable for the container lifetime). Also export `GH_TOKEN` in shell profile if useful for non-gh tools. Soft-skip with a clear message if the key is blank (non-ops fork). |
| Capabilities | **2B** — workflow dispatch/list/watch + `gh secret set` on app repos (e.g. tientje-ketama). Not required: PR create (**2C**) unless widened later. |
| Secret key | `github_token` (or `gh_token` — pick one name at implement; document in secrets template). Must cover Actions + Secrets scopes for the org/repos you operate. |

## Decide

None.

## Do

### 0. Sibling key + setup wiring

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after explicit go: add key to `task secrets:init` template + any forbidden-keys / inventory docs that list infra keys; extend `devcontainer-setup.sh` to decrypt → `gh auth login --with-token` (and soft-skip if empty); no host mount of `~/.config/gh`.

**Human must:** Mint a fine-grained (or classic) PAT with scopes for Actions read/write (dispatch) and Actions secrets on the repos you need (at least `rednaw/tientje-ketama`); SOPS into sibling; commit/push **secrets**; reopen or re-run setup so auth materializes. Never paste the token into chat.

### 1. Smoke from iac DC

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 0 and go: exact smoke commands for **2B**.

**Human must:** `gh auth status` → logged in; `gh run list --repo rednaw/tientje-ketama -L 1`; optional `gh secret list --repo rednaw/tientje-ketama` (names only).
