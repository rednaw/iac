[**<---**](README.md)

# Troubleshooting

**Secrets / SOPS**

| Problem | What to do |
|--------|------------|
| **`secrets/infra.yml` missing or cannot decrypt** | Fork setup: run **`task secrets:init`** or follow [Secrets](secrets.md). Ensure **`~/.config/sops/age/keys.txt`** exists and you are a recipient. |
| App **`Forbidden infrastructure key` on deploy** | Move infra fields out of **`apps/<app>/.iac/iac.yml`** into **`secrets/infra.yml`**. App **`iac.yml`** is plain YAML with **`image_name`** / **`app_domains`** only. |
| **`.iac/.env` cannot decrypt** | Same age recipients as **`secrets/`**: **`secrets/sops-key-*.pub`** drives **`apps/<app>/.iac/.sops.yaml`** via **`task secrets:generate-app-env-sops-config`** / **`task secrets:sync-all-app-env-sops-configs`**. After your pubkey is committed there, a teammate opens **`.iac/.env`**, saves (re-encrypt), commits. |
| "Cannot decrypt: no matching keys" | For infra: teammate opens **`secrets/infra.yml`**, saves, commits. For app: same on **`.iac/.env`**. |
| "SOPS key not found" | `task secrets:keygen` from IaC repo. Private key at **`~/.config/sops/age/keys.txt`** (bind-mounted from host). |
| VS Code doesn't decrypt | SOPS extension installed? **`sops.defaults.ageKeyFile`** in devcontainer? **`.sops.yaml`** next to the encrypted file? |
| File shows ciphertext | Install / enable SOPS extension, or use **`sops`** CLI with **`SOPS_AGE_KEY_FILE`**. |

**Terraform**

| Problem | What to do |
|--------|------------|
| "Error: authentication required" | In devcontainer: **`secrets/infra.yml`** decrypts and contains **`terraform_cloud_token`**; startup writes **`~/.terraform.d/credentials.tfrc.json`**. Outside devcontainer: **`terraform login`** or credentials file manually. |

**Connection / SSH**

| Problem | What to do |
|--------|------------|
| Connection timeout | `task server:check-status`. Ensure `dev.<base_domain>` / `prod.<base_domain>` resolve and point at the server. Server may need 30–60 s after `terraform apply`. |
| "Host key verification failed" | `task hostkeys:prepare -- <workspace>` then retry. We use `StrictHostKeyChecking=accept-new`; after a server recreate, prepare again. |

**Registry**

| Problem | What to do |
|--------|------------|
| "No repositories found" or "access denied" | Use the devcontainer (registry auth is written on first open). |
| "Could not resolve digest" / image not found | `crane ls registry.<base_domain>/<repo>`. Check tag and auth. Tag for deploy is 7 hex chars? |
| Deploy fails to pull | Server auth **`/opt/iac/.docker/config.json`**. Ansible ran? **`secrets/infra.yml`** includes **`base_domain`**, **`registry_username`**, **`registry_password`**. |
| Registry unreachable | DNS/HTTPS for `registry.<base_domain>`; Traefik and registry container running. |

**Application deployment**

| Problem | What to do |
|--------|------------|
| **`App missing …/.iac/…`** or empty **`apps/<app>`** | Ensure the app exists under **`iac/apps/<app>/`** (submodule or checkout) and **`git submodule update --init`**. Rebuild/reopen the devcontainer if you changed **`apps/`** layout ([Launch devcontainer](launch-devcontainer.md)). |
| **`Usage: task app:deploy -- <env> <app> <sha>`** | Pass **three** words after **`--`**: environment, **directory basename** under **`apps/`**, and 7-char SHA. |
| **`Forbidden infrastructure key`** | Infra keys belong in **`secrets/infra.yml`**, not **`apps/<app>/.iac/iac.yml`**. |
| Ansible playbook failures | Playbook logs; **`secrets/infra.yml`** decrypts? **`task server:check-status`**. |
| "Could not read deploy-info.yml" | App may not be deployed yet; SSH host and **`<app>`** name match **`apps/<app>`**? |

**Prefect / Workflows**

| Problem | What to do |
|--------|------------|
| Deployment not in UI | [`prefect/prefect.yaml`](../prefect/prefect.yaml) has your flow under `deployments:`? Run `task workflow:deploy -- dev`. Check playbook for "Register Prefect deployments". |
| Flow run fails immediately | Flow run logs in UI. Often: import error (add module to [`prefect/Dockerfile.worker`](../prefect/Dockerfile.worker)), wrong entrypoint in prefect.yaml, or auth (worker has socket + DOCKER_CONFIG). |
| Worker not picking up runs | `docker ps` and `docker logs prefect-worker`. UI → Work Pools → host-pool → 1 worker online. |
| Can't reach UI | `task tunnel:start -- dev`, then http://localhost:57802/. |

**Traefik**

| Problem | What to do |
|--------|------------|
| Certificates not provisioning | `docker logs traefik`. HTTP→HTTPS redirect must exclude `/.well-known/acme-challenge`; router exists. |
| HTTP→HTTPS not working | [`traefik-dynamic-redirects-http.yml.j2`](../ansible/roles/platform/templates/traefik-dynamic-redirects-http.yml.j2) priority 10000 and excludes ACME path. |
| Container not discovered | Container on `traefik` network (`docker network inspect traefik`), has `traefik.enable=true` label. |
| IPv6 not working | DNS AAAA records. Port bindings: `docker inspect traefik \| grep -A 10 Ports`. |
