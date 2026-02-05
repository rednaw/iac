# SSH Host Key Verification

**Goal:** Eliminate "host key verification failed" errors when using tasks—(re)creating the server, (re)deploying apps, bootstrap, ansible run, etc.

**Constraint:** `StrictHostKeyChecking=no` is **never** acceptable. Use `StrictHostKeyChecking=accept-new` only.

---

## 1. Background

### 1.1 How host key verification works

- SSH stores server host keys in `~/.ssh/known_hosts`.
- On connect, the client checks the server’s key against `known_hosts`:
  - **Known + match:** Connect.
  - **Known + mismatch:** "Host key verification failed" (server recreated, key changed).
  - **Unknown:** Prompt to accept (interactive) or fail (batch).
- `accept-new`: accept and add **new** keys; **reject** changed keys. No prompt. Safe for automation.
- `no`: accept anything. **Insecure**; do not use.

### 1.2 When verification fails

Typical case: **server recreated** (terraform destroy + apply, or replace).

- **Same hostname, new key:** `known_hosts` has old key for that hostname → "Host key verification failed." (DNS still points to the new server’s IP.)
- **New hostname:** No key yet → first connect uses `accept-new` → key added. No failure.

So we must **remove old keys** for the hostnames we’re about to connect to **before** running SSH/Ansible when the server may have been recreated.

### 1.3 `ssh-keygen -R`

Removes a host from `known_hosts`:

```bash
ssh-keygen -R <host> -f ~/.ssh/known_hosts
```

- `<host>` is a **hostname** (e.g. `dev.rednaw.nl`). We use hostnames only; no IPs. We skip the bracketed form `[hostname]` (that's for `[ip]:port`).

Cleanup must run **before** we SSH or run Ansible. If we only clean up inside a playbook, Ansible has already attempted the connection and failed.

---

## 2. Hostname-only, no IPs

**Recommendation:** Drop IP addresses altogether. Use **hostnames only** (e.g. `dev.rednaw.nl`, `prod.rednaw.nl` under `rednaw.nl`). Everything—inventory, SSH, known_hosts cleanup, Terraform apply/destroy, bootstrap, server tasks—uses the same hostname for each workspace.

### 2.1 Does eliminating Terraform-generated inventory help?

**Yes.** Removing the legacy Terraform-generated inventory and switching to **hardcoded inventory files with hostnames only** significantly simplifies host key handling:

| With IP-based (current) | With hostname-only (recommended) |
|-------------------------|----------------------------------|
| Terraform generates inventory from `server_ipv4` output | Hardcoded `ansible/inventory/dev.ini`, `prod.ini` with hostnames only |
| Cleanup: must obtain IP from Terraform output or parse inventory | Cleanup: **fixed hostname per workspace** (e.g. `dev` → `dev.rednaw.nl`). No Terraform, no parsing. |
| Different code paths use IP differently (apply, destroy, bootstrap, server tasks) | **Single identity:** hostname everywhere. One mapping (workspace → hostname). |
| "Run terraform apply first" needed to generate inventory | Inventory always exists. No Terraform dependency for Ansible or deploy. |
| `ssh-keygen -R` for both IP and `[IP]` | `ssh-keygen -R` for hostname only. Simpler. |

**Benefits:**

- **Static cleanup list:** Always `ssh-keygen -R dev.rednaw.nl` (or `prod.rednaw.nl`) for that workspace before Ansible. No dynamic lookup.
- **No Terraform output for SSH:** Bootstrap, server:check-status, setup-remote-cursor, apply/destroy post-steps—all use hostname. Terraform no longer needed to discover "what to connect to."
- **DNS as source of truth:** DNS is manually managed, outside this project. Hetzner typically reuses the same IP when recreating the server, so DNS rarely changes. We never touch IPs.
- **Single place for identity:** Define `dev` → `dev.rednaw.nl`, `prod` → `prod.rednaw.nl` once (e.g. Taskfile vars or a small config). All tasks use it.

### 2.2 Inventory: hardcoded, hostnames only

Replace Terraform-generated inventory with **committed** INI files, for example:

```ini
# ansible/inventory/dev.ini
[servers]
dev.rednaw.nl

[servers:vars]
ansible_user=ubuntu
ansible_python_interpreter=/usr/bin/python3
```

```ini
# ansible/inventory/prod.ini
[servers]
prod.rednaw.nl

[servers:vars]
ansible_user=ubuntu
ansible_python_interpreter=/usr/bin/python3
```

- No `ansible_host`, no IPs. Ansible connects directly to the hostname.
- `known_hosts` entries are by hostname. Cleanup uses the same hostname.

**Workspace → hostname mapping:** e.g. `dev` → `dev.rednaw.nl`, `prod` → `prod.rednaw.nl`. Keep in Taskfile vars only; use for inventory paths, cleanup, Terraform apply/destroy, bootstrap, and server tasks.

---

## 3. Touchpoints: where we SSH or use Ansible (hostname-only)

| Touchpoint | What connects | Uses inventory? | Host key handling |
|------------|----------------|-----------------|-------------------|
| **terraform:apply** | Terraform (no SSH) + post-apply `ssh` | No | `ssh-keygen -R <hostname>` **before** apply; `ssh … accept-new ubuntu@<hostname>` **after** apply. Hostname from workspace→hostname mapping. |
| **terraform:destroy** | Terraform only | No | `ssh-keygen -R <hostname>` **after** destroy. No Terraform output needed. |
| **ansible:bootstrap** | Ansible → hostname | No (`-i hostname,`) | `ssh-keygen -R <hostname>` before run. Use `ansible.cfg` → `accept-new`; remove `ANSIBLE_HOST_KEY_CHECKING=False`. |
| **ansible:run** | Ansible → inventory | Yes (hardcoded hostname) | "Prepare known_hosts" for workspace hostname **before** `ansible-playbook`. `accept-new` via `ansible.cfg`. |
| **application:deploy** | Ansible → inventory | Yes (IAC inventory, hostname) | Same "prepare known_hosts" **before** run. Use IAC `ansible.cfg` (e.g. `ANSIBLE_CONFIG`). |
| **server:check-status** | `ssh` to hostname | No | `ssh -o StrictHostKeyChecking=accept-new ubuntu@<hostname>`. Hostname from mapping. |
| **server:setup-remote-cursor** | Updates `~/.ssh/config` | No | `Host <alias>`, `HostName <hostname>`, `StrictHostKeyChecking accept-new`. No IPs. |

---

## 4. Current implementation (reference) and what changes

### 4.1 Terraform apply (`tasks/Taskfile.terraform.yml`)

**Current (IP-based):** Read `EXISTING_IP` / `NEW_IP` from `terraform output -raw server_ipv4`; `ssh-keygen -R` for IP; `ssh … ubuntu@${NEW_IP}` after apply.

**With hostname-only:** Use workspace→hostname mapping (e.g. `dev` → `dev.rednaw.nl`). **Before** apply: `ssh-keygen -R dev.rednaw.nl`. **After** apply: `ssh -o StrictHostKeyChecking=accept-new ubuntu@dev.rednaw.nl echo` to prime `known_hosts`. No Terraform output for SSH. DNS is manual, outside project; Hetzner typically reuses the same IP on recreate (§6.9).

### 4.2 Terraform destroy (`Taskfile.terraform.yml`)

**Current:** Read `SERVER_IP` from output; after destroy, `ssh-keygen -R` for IP.

**With hostname-only:** No Terraform output. **After** destroy: `ssh-keygen -R <hostname>` for that workspace. Hostname from mapping.

### 4.3 Ansible bootstrap (`tasks/Taskfile.ansible.yml`)

**Current:** `SERVER_IP` from Terraform; `ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "$SERVER_IP," bootstrap.yml`.

**With hostname-only:** Use hostname from mapping (e.g. `dev.rednaw.nl`). **Before** run: `ssh-keygen -R dev.rednaw.nl`. Run `ansible-playbook -i "dev.rednaw.nl," bootstrap.yml` **without** `ANSIBLE_HOST_KEY_CHECKING=False`; use `ansible.cfg` → `accept-new`. No Terraform output.

### 4.4 Ansible run (`tasks/Taskfile.ansible.yml` + `ansible/site.yml`)

**Current:** Inventory from Terraform-generated `inventory/$WORKSPACE.ini` (IP-based). site.yml pre_task does `ssh-keygen -R` **after** Ansible connects → ineffective.

**With hostname-only:** Hardcoded `inventory/dev.ini`, `prod.ini` with hostnames only. **Before** `ansible-playbook`: run "prepare known_hosts" for the workspace hostname (e.g. `ssh-keygen -R dev.rednaw.nl`). Remove or repurpose the site.yml pre_task.

### 4.5 Application deploy (`tasks/Taskfile.application.yml`)

**Current:** Uses IAC inventory (Terraform-generated, IP-based). No cleanup before run; runs from app root → may not use IAC `ansible.cfg`.

**With hostname-only:** Same hardcoded hostname inventory. "Prepare known_hosts" for workspace **before** `ansible-playbook`. Use `ANSIBLE_CONFIG="$IAC_REPO/ansible/ansible.cfg"` (or run from IAC) so `accept-new` is applied.

### 4.6 Server tasks (`tasks/Taskfile.server.yml`)

**Current:** `terraform output -raw server_ipv4` → `ssh … ubuntu@$SERVER_IP`; `HostName $SERVER_IP` in `~/.ssh/config`.

**With hostname-only:** Use hostname from mapping. `ssh ubuntu@dev.rednaw.nl`; `HostName dev.rednaw.nl` in config. No Terraform output. No IPs.

### 4.7 Ansible config (`ansible/ansible.cfg`)

- `host_key_checking = True`
- `ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10`

Unchanged. Ensure all Ansible invocations (including application deploy) use this config.

---

## 5. Gaps and requirements

1. **Bootstrap:** Use `accept-new` only. Remove `ANSIBLE_HOST_KEY_CHECKING=False`; rely on `ansible.cfg`. Run `ssh-keygen -R <hostname>` before bootstrap.
2. **Ansible run (site.yml):** Run `ssh-keygen -R <hostname>` **before** `ansible-playbook`, not inside the playbook. Use hardcoded hostname inventory. Keep `accept-new` via `ansible.cfg`.
3. **Application deploy:** Same "prepare known_hosts" for workspace hostname **before** run. Use IAC `ansible.cfg` (e.g. `ANSIBLE_CONFIG`). Hardcoded hostname inventory.
4. **Consistency:** All SSH/Ansible usage uses `StrictHostKeyChecking=accept-new`; no `no` anywhere.
5. **Hostname-only:** No IPs. Single workspace→hostname mapping (e.g. `dev` → `dev.rednaw.nl`, `prod` → `prod.rednaw.nl`). All touchpoints use hostname.

---

## 6. Fix strategy (hostname-only)

### 6.1 Workspace → hostname mapping

Define **one** mapping used everywhere, e.g.:

| Workspace | Hostname       |
|-----------|----------------|
| `dev`     | `dev.rednaw.nl`  |
| `prod`    | `prod.rednaw.nl` |

Keep it in a single place: **Taskfile vars only**. All tasks (terraform, ansible, server, application) use it.

### 6.2 Eliminate Terraform-generated inventory

- Remove Terraform's `local_file` that writes `ansible/inventory/*.ini` from `inventory.ini.tpl`.
- Add **committed** `ansible/inventory/dev.ini` and `ansible/inventory/prod.ini` with hostnames only (see §2.2). Remove these paths from `.gitignore` if present.
- No IPs, no `ansible_host`. Ansible connects to the hostname directly.

### 6.3 Shared "prepare known_hosts" step

A **single** way to prepare `known_hosts` for a workspace **before** any SSH/Ansible use:

- **Input:** Workspace (e.g. `dev` / `prod`) or directly the hostname.
- **Behavior:** `ssh-keygen -R <hostname>` on `~/.ssh/known_hosts` (ignore errors if not present). No bracketed form.
- **Call sites:** terraform apply (before), terraform destroy (after), bootstrap (before), ansible:run (before), application:deploy (before).

With hostname-only, no inventory parsing is needed—just workspace→hostname mapping. A small script or Taskfile logic is enough.

### 6.4 Bootstrap

- Use hostname from mapping (e.g. `dev.rednaw.nl`). **Before** run: `ssh-keygen -R <hostname>`.
- `ansible-playbook -i "<hostname>," bootstrap.yml` **without** `ANSIBLE_HOST_KEY_CHECKING=False`. Use `ansible.cfg` → `accept-new`.
- No Terraform output.

### 6.5 Ansible run

- **Before** `ansible-playbook -i inventory/$WORKSPACE.ini site.yml`: run "prepare known_hosts" for the workspace hostname.
- Inventory = hardcoded hostname INI files. **Remove** the site.yml pre_task that does `ssh-keygen -R` (it runs after connect, so it can't fix verification failures).

### 6.6 Application deploy

- **Before** `ansible-playbook`: same "prepare known_hosts" for workspace hostname.
- Use IAC inventory (hardcoded hostname) and IAC `ansible.cfg`, e.g. `ANSIBLE_CONFIG="$IAC_REPO/ansible/ansible.cfg"`.

### 6.7 Terraform apply / destroy

- **Apply:** Before apply, `ssh-keygen -R <hostname>`. After apply, `ssh -o StrictHostKeyChecking=accept-new ubuntu@<hostname> echo`. Hostname from mapping. No Terraform output for SSH.
- **Destroy:** After destroy, `ssh-keygen -R <hostname>`. No Terraform output.

### 6.8 Server tasks

- **check-status:** `ssh -o StrictHostKeyChecking=accept-new ubuntu@<hostname>`. Hostname from mapping. No Terraform output.
- **setup-remote-cursor:** `Host <alias>`, `HostName <hostname>`, `StrictHostKeyChecking accept-new`. No IPs. Hostname from mapping.

### 6.9 DNS

- DNS (e.g. `dev.rednaw.nl`, `prod.rednaw.nl`) is **manually managed, outside this project**. In practice Hetzner assigns the same IP when recreating the server, so DNS rarely needs updating. Hostname-based SSH/Ansible works as long as DNS points at the server.

---

## 7. What still needs to be decided

Decisions below. **Err on simplicity; no backwards compatibility.**

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | **Exact hostnames** | `dev.rednaw.nl` / `prod.rednaw.nl` vs `platform-dev.rednaw.nl` / `platform-prod.rednaw.nl` | **`dev.rednaw.nl` / `prod.rednaw.nl`** — shorter, doc already uses them. Use consistently everywhere. |
| 2 | **Where to keep workspace→hostname mapping** | Taskfile `vars` vs `scripts/hostname-for-workspace.sh` | **Taskfile vars only** — one place, no extra script. |
| 3 | **`ssh-keygen -R "[hostname]"` (bracketed form)** | Do it or skip | **Skip** — bracketed form is for `[ip]:port`. Hostnames don’t need it. |
| 4 | **site.yml pre_task** (`ssh-keygen -R` delegated to localhost) | Remove vs keep as “best-effort” | **Remove** — it runs after Ansible connects, so it never fixes verification. Redundant once we do pre-connection cleanup. |
| 5 | **setup-remote-cursor: `Host` alias** | `Host dev` + `HostName dev.rednaw.nl` vs `Host dev.rednaw.nl` + `HostName dev.rednaw.nl` | **`Host dev` / `Host prod`**, `HostName dev.rednaw.nl` / `prod.rednaw.nl` — short alias, same workspace→hostname mapping. |
| 6 | **DNS** | Terraform-managed vs manual, outside project | **Manual, outside this project.** In practice Hetzner assigns the same IP when recreating the server, so DNS rarely needs changing. |
| 7 | **Terraform `server_ipv4` output** | Keep vs remove | **Keep** — useful for DNS A records, `ssh` command output, debugging. **Do not use** in Taskfiles; all SSH/Ansible uses hostname. |
| 8 | **“Prepare known_hosts”** | Taskfile-only vs `scripts/prepare-known-hosts.sh` | **Taskfile-only** — e.g. a `hostkeys:prepare` task that takes workspace, runs `ssh-keygen -R <hostname>`. Others call it. No new script. |
| 9 | **`inventory_hostname` → dev/prod** | nginx.yml, certbot.yml use `'dev' if '-dev' in inventory_hostname else 'prod'`. With hostname `dev.rednaw.nl` there’s no `-dev`. | **Switch to hostname-based check:** e.g. `'dev' if 'dev.' in inventory_hostname else 'prod'` (or `'prod' if 'prod.' in inventory_hostname else 'dev'`). |

**Already decided (no flexibility):**

- No IPs for SSH/Ansible. Hostname only.
- No `StrictHostKeyChecking=no` or `ANSIBLE_HOST_KEY_CHECKING=False`. `accept-new` only.
- Remove Terraform inventory generation. Hardcoded `ansible/inventory/dev.ini`, `prod.ini`.
- Remove `ansible/inventory/*.ini` from `.gitignore` — we commit them.
- Terraform `server_name` (e.g. `platform-dev`) stays for **Hetzner server name** only. SSH/Ansible use **hostname** only.

---

## 8. Checklist

- [x] **Workspace→hostname mapping:** Define `dev` → `dev.rednaw.nl`, `prod` → `prod.rednaw.nl` in Taskfile vars only. Use it everywhere.
- [x] **Eliminate Terraform inventory:** Remove Terraform `local_file` + `inventory.ini.tpl` generation. Stop using `server_ipv4` / `server_ip` for SSH or Ansible.
- [x] **Hardcoded hostname inventory:** Add `ansible/inventory/dev.ini` and `prod.ini` with hostnames only. Commit them; remove from `.gitignore` if present.
- [x] **"Prepare known_hosts":** Taskfile-only: `hostkeys:prepare` task, given workspace runs `ssh-keygen -R <hostname>`. Use before apply, after destroy, before bootstrap, before ansible:run, before application:deploy. No `[hostname]`.
- [x] **terraform:apply / destroy:** Use hostname from mapping for cleanup and post-apply `ssh`. No Terraform output for SSH.
- [x] **ansible:bootstrap:** Use hostname; remove `ANSIBLE_HOST_KEY_CHECKING=False`; run "prepare known_hosts" before. No Terraform output.
- [x] **ansible:run:** Use hardcoded inventory. Run "prepare known_hosts" before `ansible-playbook`. Remove site.yml pre_task that does `ssh-keygen -R`.
- [x] **application:deploy:** Same "prepare known_hosts" before run. Use IAC `ansible.cfg` (e.g. `ANSIBLE_CONFIG`). Hardcoded hostname inventory.
- [x] **server:check-status / setup-remote-cursor:** Use hostname from mapping. No IPs, no Terraform output.
- [x] **No IPs anywhere:** Grep for `server_ipv4`, `server_ip`, `ansible_host` (if used for IP), and any IP-based logic; replace with hostname.
- [x] **No `StrictHostKeyChecking=no` or `ANSIBLE_HOST_KEY_CHECKING=False`** anywhere.
- [x] **nginx/certbot `inventory_hostname`:** Replace `'dev' if '-dev' in inventory_hostname else 'prod'` with hostname-based check (`'dev' if 'dev.' in inventory_hostname else 'prod'`). See §7.9.
- [x] **DNS:** Manual, outside project. Ensure `dev.rednaw.nl` / `prod.rednaw.nl` point at the right server(s). Hetzner typically reuses the same IP on recreate.

---

## 9. References

- **Terraform apply/destroy:** `tasks/Taskfile.terraform.yml`  
- **Bootstrap / Ansible run:** `tasks/Taskfile.ansible.yml`  
- **Application deploy:** `tasks/Taskfile.application.yml`  
- **Server tasks:** `tasks/Taskfile.server.yml`  
- **Ansible config:** `ansible/ansible.cfg`  
- **Site playbook:** `ansible/site.yml`  
- **Inventory:** `ansible/inventory/dev.ini`, `ansible/inventory/prod.ini` (hardcoded hostnames)  
- **Troubleshooting:** `docs/TROUBLESHOOTING.md`
