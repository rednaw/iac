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
| App host | Apex `tientjeketama.nl` canonical; `www.` 301 → apex. No special `prod.` DNS or redirect (same as any other subdomain). Contract `app_domains: [tientjeketama.nl]`; deploy uses the first entry |
| TFC | `platform-prod` → `platform`, `vpn-prod` → `vpn` (TFC rename keeps state); backends `workspaces { name = … }` — no prefix mode, no `workspace select` |
| Authelia plan | Its `when: app_environment == 'prod'` guard goes away; `app_environment` fact is deleted here |
| Admin transition | No platform hostname. Keep `task tunnel:*` + `portal.html` (API-IP based) until Authelia; no `dev`/`prod` tunnel args |
| SSH alias | Managed `~/.ssh/config.d/iac-admin`: `Host platform` → API IPv4 (no LocalForward; no `dev`/`prod` Host blocks) |

## Decide

None.

## Do

Checkboxes track status only. The agent may change only **Agent** boxes; only the human may change **Human** boxes. Task bodies assign the work.

### 0. Dev-only removal

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — can start now:
- `terraform/platform/dns.tf`: delete `is_dev`, `dev_a`/`dev_aaaa`, `app_dev_a`/`app_dev_aaaa`, dev section comment.
- `ansible/roles/platform/tasks/traefik.yml`: delete "Remove redirect config on dev" task; redirects task loses its `when`.

**Human must:** Open Terraform Cloud, confirm `platform-dev` has no resources/state worth retaining, then delete that workspace.

### 1. Terraform

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — can start now:
- `terraform/platform/locals.tf`: drop `environment`, `project_slug`; `server_name = "platform"`, `firewall_name = "platform-firewall"` (keep `var.server_name` override only if something sets it). `main.tf`: drop `environment` label (`ssh-allow-me.sh` already selects by `iac_managed=true`).
- `terraform/platform/versions.tf` → `workspaces { name = "platform" }`; `terraform/vpn/versions.tf` → `workspaces { name = "vpn" }`.
- `dns.tf`: delete platform `prod_a`/`prod_aaaa` and app `app_prod_a`/`_aaaa`; `is_prod` gating removed (all records unconditional); `www` CNAME → apex (`${local.site_domain}.`).
- `tasks/Taskfile._terraform.yml`: drop `WORKSPACE`/`WORKSPACES`, `workspace select`, `TF_WORKSPACE` init handling, the reconfigure loop; `tasks/Taskfile.platform.yml` + `tasks/Taskfile.vpn.yml` callers follow.

**Human must:** In Terraform Cloud, rename `platform-prod` → `platform` and `vpn-prod` → `vpn`. During cutover, run `terraform init -reconfigure`, inspect the platform plan for in-place renames and DNS changes only, then apply it.

### 2. Ansible

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — can start now:
- `roles/platform/tasks/traefik.yml`: delete `app_environment`, `traefik_app_domains`; `traefik_redirect_target` → `site_domain`.
- `templates/traefik-dynamic-redirects.yml.j2`: delete apex router (app serves apex); `www.` only 301 → `https://<site_domain>$path` (no `prod.` redirect).
- Delete `templates/traefik-dynamic-app-host.yml.j2` and its deploy task; remove the stale `/etc/traefik/dynamic/app-host.yml` with a `state: absent` task.
- `roles/deploy_app/tasks/prepare-server.yml`: `app_host` = first `app_domains` entry; drop `workspace` var there, in `main.yml`, `playbooks/deploy-app.yml`, `playbooks/prefect-deploy.yml`.
- `tasks/Taskfile._ansible.yml`: inventory `platform` (vpn stays `vpn`); delete `hostkeys:platform` and its callers in `Taskfile.app.yml`, `Taskfile.workflow.yml`.

**Human must:** During cutover, run `task platform:configure:apply` after Terraform succeeds.

### 3. Tasks and scripts

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — can start now:
- `Taskfile.yml`: delete `_check:workspace`; help text without `[dev|prod]`.
- Drop the env arg and shift positionals: `tasks/Taskfile.platform.yml` (`provision:*`, `configure:*`), `Taskfile.app.yml` (`app:deploy -- <app> <sha>`, `app:versions -- <app>`), `Taskfile.backup.yml` (`backup:* -- <app> …`), `Taskfile.workflow.yml`, `Taskfile.hostkeys.yml` (`-- platform|vpn`; delete `hostname` and now-useless name-key cleanup in `prepare`; rewrite header comment), `Taskfile.server.yml` (`check-status`: one box via `hostkeys:ip -- platform`).
- `scripts/application_versions.py`, `scripts/validate-stack.py`: drop workspace arg; `scripts/validate-taskfiles.py` fixture `CLI_ARGS=(dev …)`.
- `.devcontainer/devcontainer-setup.sh`: keep only the local `host` Docker context; keep `.devcontainer/setup-remote-ssh.sh` writing `Host platform` → API IPv4 (drop `dev`/`prod` Host blocks and LocalForward); delete unused `.devcontainer/tunnel-start.sh`; keep `forwardPorts` 57800–57802 so the host browser can hit `task tunnel:start`.
- Keep `tasks/Taskfile.tunnel.yml` + `portal.html`; retarget to API IPv4 (`hostkeys:ip -- platform`), no env arg.
- `tasks/Taskfile.secrets.yml`: “dev/prod contexts” template comment → single platform.
- `.cursor/rules/app-deploy.mdc`: contract selects the first `app_domains` entry and commands no longer take `<env>`.

**Human must:** Rebuild the devcontainer after merging these changes. Use the new commands without `dev`/`prod`; `task tunnel:start` for admin UIs until Authelia.

### 4. App contract

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — can start now: update the `iac` deployment role to consume the first `app_domains` entry and provide/verify this sibling patch.

**Human must:** In the separate `tientje-ketama` repo:
- `.iac/iac.yml`: `app_domains: [tientjeketama.nl]` (lands together with the cutover — deploy with the old contract would pick `prod.`).
- `.cursor/rules/project.mdc`: production is the apex only; fix the incorrect `auth.tientjeketama.nl` statement (CMS OAuth is `auth.rednaw.nl`).
- `.cursor/rules/deploy.mdc`: deploy command loses `<env>`.
Then commit it and provide the seven-character image SHA for deployment. No runtime URL migration is needed: Simple Analytics already uses `tientjeketama.nl`; there are no canonical, cookie-domain, CORS or origin settings tied to `prod.`.

### 5. Cutover (operator, one sitting)

- [x] Agent: implemented
- [x] Human: reviewed

**Agent inspected (2026-09-24):**
- TFC backends `platform` / `vpn` init OK (renames already done).
- `hcloud`: server `platform`, firewall `platform-firewall` — already renamed.
- `task platform:provision:plan` → **No changes** (DNS/prod.rednaw gone; `prod.`/`www.` app records present).
- `task vpn:provision:plan` → **not** empty: wants to create `hcloud_primary_ip.v4` then errors (`allowed_ssh_ips` null). **Do not apply vpn** as part of this cutover; no VPN box is running.
- Live Traefik already has www/prod → apex redirects; `app-host.yml` absent. Configure for Traefik is effectively done; re-run is still safe/idempotent.
- **Broken until app redeploy:** `APP_HOST=prod.tientjeketama.nl` while apex is the only non-redirect host → `https://tientjeketama.nl` 404. Image tag `da75969` is in the registry (contract commit).
- Fact cache dir `/tmp/ansible_facts` empty/absent — skip unless a `rednaw-prod` file appears.

**Human must:** Execute remaining steps (TF already applied):

```bash
# 1–3 already done for platform; skip vpn apply
rm -f /tmp/ansible_facts/rednaw-prod   # no-op if missing
task platform:configure:apply          # idempotent Traefik confirm
task app:deploy -- tientje-ketama da75969
# prove apex 200 + redirects; tunnel already proven earlier:
curl -sI https://tientjeketama.nl/ | head -5
curl -sI https://www.tientjeketama.nl/ | head -5
# prod. should not resolve (like any other unused subdomain):
# curl -sI https://prod.tientjeketama.nl/ → could not resolve host
task tunnel:start   # + portal.html if needed
```

After dropping `prod.` DNS/redirect (same sitting or follow-up):
```bash
task platform:provision:plan   # expect destroy app_prod_a / app_prod_aaaa only
task platform:provision:apply
task platform:configure:apply  # www-only redirect
```

### 6. Docs and rules

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — after 3:
- `README.md`, `.cursor/rules/terraform.mdc`, `docs/future/README.md`, `docs/future/honeypot.md`, `docs/future/ssh-admin-t2.md`, `docs/future/vpn-travel-china.md` **and its operator manual**: remove stale environment/workspace/name commands (`vpn-prod` also becomes `vpn`).
- `.cursor/plans/authelia.md`: drop the prod-only guard and compatibility cleanup; `remove-dev.md` already removes the tunnel and platform `prod.` DNS.
- No changes to the parent portfolio README or other app repos: searches found no old hosts there. Sveltia tenants keep `auth.rednaw.nl`; the reusable image workflow and `tientje-ketama` repository variables keep `registry.rednaw.nl`.

**Human must:** In the native `rednaw` repo, update and commit `.cursor/skills/rednaw-map/SKILL.md`: `tientje-ketama` ships at the apex, not `dev`/`prod`; platform and VPN workspace names are singular.

### 7. Verify

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — after 5: run automated and read-only checks:
- `task test` green; both exact-name TFC backends initialize; platform plan after apply is empty; VPN plan is empty.
- `hcloud server list` shows `platform`, same IPs; host-key accept, Ansible inventory and `task server:check-status` use the API IP.
- `curl -I https://tientjeketama.nl` → 200; `https://www.tientjeketama.nl` → 301 apex; `prod.tientjeketama.nl` does not resolve.
- `task app:deploy`, `task backup:snapshots -- tientje-ketama`, `task workflow:deploy`, `task hostkeys:accept -- platform|vpn`, and the one-off API-IP dashboard tunnel work.
- Search `iac` plus `tientje-ketama` and the shared `rednaw-map` for stale operational `dev`/`prod` task arguments, platform hosts, inventory names and TFC workspaces; allow only development-tool terms such as devcontainer and `iac-dev`.

**Human must:** Open both Sveltia tenants and start their GitHub OAuth flows; confirm registry image push/pull, deployment, backup and workflow commands; then accept the cutover.
