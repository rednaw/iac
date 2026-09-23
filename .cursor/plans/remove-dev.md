[**<---**](../rules/project.mdc)

# Remove the dev environment

Platform runs as one VPS. The dev workspace (second Hetzner box, `dev.*` DNS, `-- dev|prod` everywhere) is unused in practice: too expensive and cumbersome. Remove it from Terraform, Ansible, tasks, scripts, app contracts and docs, and drop the `prod` label itself — there is only one platform.

## Decided

| | |
|--|--|
| Why | Dev box costs money and a second apply per change; not used |
| Live state | No dev server running (`hcloud server list`: only `rednaw-nl-prod`); `dev.rednaw.nl` / `dev.tientjeketama.nl` don't resolve — nothing live to destroy |
| Staging | None. Platform changes land on the box directly; pre-flight is `task test` (lint, syntax, validate scripts) only |
| Scope of "prod" | Gone everywhere: no env argument on tasks (`task platform:configure:apply`, `task app:deploy -- <app> <sha>`), no `prod` in server/firewall/workspace/host names, no `environment` label |
| Names | Mirror VPN: server `platform`, firewall `platform-firewall`, Ansible inventory `platform`; `hostkeys:platform` derivation removed |
| In-place renames | `hcloud_server.name`, firewall name and labels update in place (no recreate) — confirm in the plan output before apply |
| Platform host | `prod.<base_domain>` dropped, like the VPN box (no DNS name). SSH/Ansible already use API IPv4 (`hostkeys:ip`, IPv4-keyed `known_hosts`); `server:check-status` switches to IPv4; `app-host` ACME router + template deleted |
| App host | Apex `tientjeketama.nl` canonical; `www.` and `prod.` 301 → apex (old links + HSTS keep working). Contract `app_domains: [tientjeketama.nl]`; deploy uses the first entry |
| TFC | `platform-prod` → `platform`, `vpn-prod` → `vpn` (TFC rename keeps state); backends `workspaces { name = … }` — no prefix mode, no `workspace select` |
| Authelia plan | Its `when: app_environment == 'prod'` guard goes away; `app_environment` fact is deleted here |
| Admin transition | No compatibility tunnel or platform hostname. Remove both here; until Authelia lands, an explicit API-IP `ssh -L` remains available as break-glass |

## Decide

None.

## Do

Checkboxes track status only. The agent may change only **Agent** boxes; only the human may change **Human** boxes. Task bodies assign the work.

### 0. Dev-only removal

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now:
- `terraform/platform/dns.tf`: delete `is_dev`, `dev_a`/`dev_aaaa`, `app_dev_a`/`app_dev_aaaa`, dev section comment.
- `ansible/roles/platform/tasks/traefik.yml`: delete "Remove redirect config on dev" task; redirects task loses its `when`.

**Human must:** Open Terraform Cloud, confirm `platform-dev` has no resources/state worth retaining, then delete that workspace.

### 1. Terraform

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now:
- `terraform/platform/locals.tf`: drop `environment`, `project_slug`; `server_name = "platform"`, `firewall_name = "platform-firewall"` (keep `var.server_name` override only if something sets it). `main.tf`: drop `environment` label (`ssh-allow-me.sh` already selects by `iac_managed=true`).
- `terraform/platform/versions.tf` → `workspaces { name = "platform" }`; `terraform/vpn/versions.tf` → `workspaces { name = "vpn" }`.
- `dns.tf`: delete platform `prod_a`/`prod_aaaa`; `is_prod` gating removed (all records unconditional); `www` CNAME → apex (`${local.site_domain}.`); keep `app_prod_a`/`_aaaa` as the distinct legacy redirect host for `prod.tientjeketama.nl`.
- `tasks/Taskfile._terraform.yml`: drop `WORKSPACE`/`WORKSPACES`, `workspace select`, `TF_WORKSPACE` init handling, the reconfigure loop; `tasks/Taskfile.platform.yml` + `tasks/Taskfile.vpn.yml` callers follow.

**Human must:** In Terraform Cloud, rename `platform-prod` → `platform` and `vpn-prod` → `vpn`. During cutover, run `terraform init -reconfigure`, inspect the platform plan for in-place renames and DNS changes only, then apply it.

### 2. Ansible

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now:
- `roles/platform/tasks/traefik.yml`: delete `app_environment`, `traefik_app_domains`; `traefik_redirect_target` → `site_domain`.
- `templates/traefik-dynamic-redirects.yml.j2`: delete apex router (app serves apex); `www.` and `prod.<site_domain>` routers 301 → `https://<site_domain>$path`.
- Delete `templates/traefik-dynamic-app-host.yml.j2` and its deploy task; remove the stale `/etc/traefik/dynamic/app-host.yml` with a `state: absent` task.
- `roles/deploy_app/tasks/prepare-server.yml`: `app_host` = first `app_domains` entry; drop `workspace` var there, in `main.yml`, `playbooks/deploy-app.yml`, `playbooks/prefect-deploy.yml`.
- `tasks/Taskfile._ansible.yml`: inventory `platform` (vpn stays `vpn`); delete `hostkeys:platform` and its callers in `Taskfile.app.yml`, `Taskfile.workflow.yml`.

**Human must:** During cutover, run `task platform:configure:apply` after Terraform succeeds.

### 3. Tasks and scripts

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now:
- `Taskfile.yml`: delete `_check:workspace`; help text without `[dev|prod]`.
- Drop the env arg and shift positionals: `tasks/Taskfile.platform.yml` (`provision:*`, `configure:*`), `Taskfile.app.yml` (`app:deploy -- <app> <sha>`, `app:versions -- <app>`), `Taskfile.backup.yml` (`backup:* -- <app> …`), `Taskfile.workflow.yml`, `Taskfile.hostkeys.yml` (`-- platform|vpn`; delete `hostname` and now-useless name-key cleanup in `prepare`; rewrite header comment), `Taskfile.server.yml` (`check-status`: one box via `hostkeys:ip -- platform`).
- `scripts/application_versions.py`, `scripts/validate-stack.py`: drop workspace arg; `scripts/validate-taskfiles.py` fixture `CLI_ARGS=(dev …)`.
- `.devcontainer/devcontainer-setup.sh`: keep only the local `host` Docker context; delete `.devcontainer/setup-remote-ssh.sh` and unused `.devcontainer/tunnel-start.sh`; remove dashboard `forwardPorts` from `devcontainer.json`.
- Delete `tasks/Taskfile.tunnel.yml` and `portal.html`; drop the `tunnel` include/help from `Taskfile.yml` and its README command. Document an explicit `ssh -L 57800:localhost:57800 -L 57801:localhost:57801 -L 57802:localhost:57802 ubuntu@$(task hostkeys:ip -- platform)` only as break-glass, not a task or alias.
- `tasks/Taskfile.secrets.yml`: “dev/prod contexts” template comment → single platform.
- `.cursor/rules/app-deploy.mdc`: contract selects the first `app_domains` entry and commands no longer take `<env>`.

**Human must:** Rebuild the devcontainer after merging these changes. Use the new commands without `dev`/`prod`; use the documented one-off `ssh -L` command only if dashboard access is needed before Authelia.

### 4. App contract

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now: update the `iac` deployment role to consume the first `app_domains` entry and provide/verify this sibling patch.

**Human must:** In the separate `tientje-ketama` repo:
- `.iac/iac.yml`: `app_domains: [tientjeketama.nl]` (lands together with the cutover — deploy with the old contract would pick `prod.`).
- `.cursor/rules/project.mdc`: production is the apex only; fix the incorrect `auth.tientjeketama.nl` statement (CMS OAuth is `auth.rednaw.nl`).
- `.cursor/rules/deploy.mdc`: deploy command loses `<env>`.
Then commit it and provide the seven-character image SHA for deployment. No runtime URL migration is needed: Simple Analytics already uses `tientjeketama.nl`; there are no canonical, cookie-domain, CORS or origin settings tied to `prod.`.

### 5. Cutover (operator, one sitting)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 0–4: prepare the exact cutover commands and inspect the Terraform plans/output for replacement or drift.

**Human must:** Execute this in one sitting:
1. TFC: delete `platform-dev`; rename `platform-prod` → `platform`, `vpn-prod` → `vpn`.
2. `terraform init -reconfigure` in both roots; `task platform:provision:plan` → only in-place server/firewall rename, label change, DNS changes. Then apply.
3. `task vpn:provision:plan` → no changes.
4. Delete the old Ansible fact cache entry for `rednaw-prod`.
5. `task platform:configure:apply` (Traefik redirects, app-host removal).
6. `task app:deploy -- tientje-ketama <sha>` (new `APP_HOST` = apex).
7. If dashboard access is needed before Authelia, prove the documented one-off API-IP `ssh -L` command; there is no persistent tunnel or platform DNS compatibility layer.

### 6. Docs and rules

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 3:
- `README.md`, `.cursor/rules/terraform.mdc`, `docs/future/README.md`, `docs/future/honeypot.md`, `docs/future/ssh-admin-t2.md`, `docs/future/vpn-travel-china.md` **and its operator manual**: remove stale environment/workspace/name commands (`vpn-prod` also becomes `vpn`).
- `.cursor/plans/authelia.md`: drop the prod-only guard and compatibility cleanup; `remove-dev.md` already removes the tunnel and platform `prod.` DNS.
- No changes to the parent portfolio README or other app repos: searches found no old hosts there. Sveltia tenants keep `auth.rednaw.nl`; the reusable image workflow and `tientje-ketama` repository variables keep `registry.rednaw.nl`.

**Human must:** In the native `rednaw` repo, update and commit `.cursor/skills/rednaw-map/SKILL.md`: `tientje-ketama` ships at the apex, not `dev`/`prod`; platform and VPN workspace names are singular.

### 7. Verify

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 5: run automated and read-only checks:
- `task test` green; both exact-name TFC backends initialize; platform plan after apply is empty; VPN plan is empty.
- `hcloud server list` shows `platform`, same IPs; host-key accept, Ansible inventory and `task server:check-status` use the API IP.
- `curl -I https://tientjeketama.nl` → 200; `https://www.tientjeketama.nl` and `https://prod.tientjeketama.nl` → 301 apex; paths and query strings survive redirects.
- `task app:deploy`, `task backup:snapshots -- tientje-ketama`, `task workflow:deploy`, `task hostkeys:accept -- platform|vpn`, and the one-off API-IP dashboard tunnel work.
- Search `iac` plus `tientje-ketama` and the shared `rednaw-map` for stale operational `dev`/`prod` task arguments, platform hosts, inventory names and TFC workspaces; allow only the old app redirect host and development-tool terms such as devcontainer and `iac-dev`.

**Human must:** Open both Sveltia tenants and start their GitHub OAuth flows; confirm registry image push/pull, deployment, backup and workflow commands; then accept the cutover.
