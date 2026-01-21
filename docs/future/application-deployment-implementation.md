# Application Deployment — Implementation Spec

Structured specification for implementers and automation. Input to an AI or tool that implements the application deployment and registry workflow.  
Keep this document in sync with **application-deployment.md** (human-oriented description).

✅ = done  
⬜ = open / pending

---

## Purpose / Intended Capability

Add an **application deployment** capability that provides:

* **Private registry:** self-hosted OCI/Docker registry with auth; images built in CI and pushed with SHA tags.
* **Manual promotion and deploy:** one task promotes an image (semantic tag + push) and deploys via Ansible. No automatic production deployment.
* **App-owned deploy logic:** each app has `app/iac/deploy.yml` (Ansible playbook) and deployment descriptors in `app/iac/`.
* **Secrets:** SOPS; app secrets in `app/iac/env.enc` (same SOPS/age key as infrastructure), decrypted to `.env` on the server by Ansible.
* **Observability:** Crane for read-only registry inspection; optional pruning of SHA-only tags.

**Audience:** small team (2–3); low ceremony; full visibility and control.

---

## Deployment & Observation Workflow

### 1. CI Build & Push

* Build the container image per commit.
* Tag with **full 40-character commit SHA**.
* Optionally tag with a **provisional** tag (e.g. `1.2.3-rc`) for QA.
* Push **only** to the private registry.

CI **must not** assign final semantic versions or trigger deployments.

---

### 2. Single Manual Deploy Task

**Command:** `task registry:deploy -- <WORKSPACE> <CONFIG_FILE_PATH>`

**Arguments:**

* `<WORKSPACE>` → `dev` or `prod` (mandatory).
* `<CONFIG_FILE_PATH>` → path to the **deployment descriptor** (mandatory). The file’s parent directory must be named exactly `iac`; its extension must be `.yml` or `.yaml`. Examples: `apps/hello/iac/dev.yml`, `../MilledonAI/iac/prod.yml`.

**Example:**

```bash
task registry:deploy -- dev apps/hello/iac/dev.yml
task registry:deploy -- prod ../MilledonAI/iac/prod.yml
```

**Deployment descriptor (YAML):**

* **Location:** The file must satisfy: (1) the immediate parent directory of the file is named exactly `iac`; (2) the file extension is `.yml` or `.yaml`. The basename is otherwise unrestricted (e.g. `dev.yml`, `prod.yml`).
* **Required fields:**
  * `registry_name` → registry domain (e.g. `registry.rednaw.nl`)
  * `image_name` → image name without registry (e.g. `rednaw/hello-world`)
  * `sha` → full 40‑hex commit SHA, no prefix
  * `semver` → semantic version, no `v` prefix (e.g. `1.2.3`)
  * `service_name` → name of the service in `app/iac/docker-compose.yml` to which the image applies

**Example descriptor:**

```yaml
registry_name: registry.rednaw.nl
image_name: rednaw/hello-world
sha: f2f8d1dd6f2af2427baddc14334c2a13362696fd
semver: 1.2.3
service_name: hello-world
```

**Convention over configuration (no overrides):**

* **App root** = the parent directory of the `iac` directory that contains the descriptor. Example: descriptor `../MilledonAI/iac/prod.yml` → app root `../MilledonAI`.
* **Deploy playbook** = `app_root/iac/deploy.yml`.
* **Deploy target on server** = `/opt/giftfinder/<app_slug>`, where `app_slug` = basename of `app_root` (e.g. `hello` from `apps/hello`, `MilledonAI` from `../MilledonAI`). There is no configuration to override this path.

**What the task does (in order):**

1. Validate `WORKSPACE` and `CONFIG_FILE_PATH`: `WORKSPACE` in `{dev,prod}`; file exists; its parent directory is named `iac`; its extension is `.yml` or `.yaml`.
2. Read and validate the descriptor (YAML, required fields, SHA format, semver format).
3. Derive app root and `app_root/iac/deploy.yml`.
4. Construct image reference: `{{registry_name}}/{{image_name}}:{{sha}}`.
5. Authenticate to the registry locally (SOPS-decrypted infra secrets; no decrypted file on disk).
6. Pull the SHA-tagged image from the registry (verify it exists).
7. Check that the semantic tag does **not** exist → **fail** if it does.
8. Tag that image with the semantic tag and push to the registry.
9. Invoke Ansible to deploy. IAC: decrypts infrastructure secrets; decrypts `app_root/iac/env.enc` to `deploy_target/.env` if `app_root/iac/env.enc` exists; copies `app_root/iac/docker-compose.yml` to `deploy_target/docker-compose.yml`; runs the app’s `iac/deploy.yml` with extra vars `image`, `service_name`, `deploy_target`.
10. Run Crane read-only checks: verify `{{registry_name}}/{{image_name}}:{{semver}}` exists and its digest matches the digest of the pushed SHA-tagged image (see §Crane in `registry:deploy`).

If any step fails, the task fails with a clear error.

---

### 3. Optional Pruning / Cleanup

* SHA-only tags may be pruned manually after a retention period (e.g. 7–14 days).
* Semantic tags are **never** pruned.
* Crane tasks support inspection and identifying prune candidates.

---

### Pruning Insight & Storage Monitoring

* **List tags:** `crane ls <registry>/<image>`
* **Filter SHA-like tags:** e.g. `grep -E '^[0-9a-f]{7,40}$'`
* **Inspect manifest/labels:** `crane manifest <ref>`, `crane digest <ref>`
* **Compare with deployed:** `docker inspect <container>` for `Image`
* **Delete SHA-only:** `crane delete <registry>/<image>:<sha>`
* **Disk usage:** `du -sh /var/lib/registry/...` on registry host; `docker system df` on app servers.

---

### Workflow Diagram (Textual)

```
Commit → CI build → Full SHA tag (40 chars) → push to registry
          ↓
(Optional) Provisional tag (e.g. 1.2.3-rc) for QA
          ↓
Ops run: task registry:deploy -- <WORKSPACE> <CONFIG_FILE_PATH>
          ↓
  - Validate WORKSPACE and descriptor (parent dir of file is iac, ext .yml or .yaml)
  - Read and validate descriptor (SHA, semver, fields)
  - Derive app root, deploy_target
  - Construct image ref
  - Auth to registry (SOPS, no decrypted file on disk)
  - Pull SHA image, check semver tag does not exist
  - Tag with semver, push to registry
  - Ansible: decrypt iac/env.enc→.env, copy iac/docker-compose.yml to deploy_target, run app iac/deploy.yml with image, service_name, deploy_target
  - Crane: read-only verification
          ↓
Optional: prune old SHA-only tags (manual)
```

---

## Decision Table

| Decision | Choice / Notes | Done? |
|----------|----------------|-------|
| Registry | Docker/OCI v3, htpasswd, SOPS for credentials | ✅ |
| CI tagging | Full SHA (40 chars) + optional provisional | ✅ |
| Deploy command | `registry:deploy -- <WORKSPACE> <CONFIG_FILE_PATH>` | ✅ |
| Deployment descriptor | YAML in a directory named `iac`, ext `.yml` or `.yaml`; parent of that dir = app root | ✅ |
| Descriptor fields | registry_name, image_name, sha, semver, service_name | ✅ |
| Compose file | `app/iac/docker-compose.yml` plain file, no templating; service has `image: ${IMAGE}` | ✅ |
| App deploy playbook | `app/iac/deploy.yml` creates host dirs for volume mounts, then runs `docker_compose_v2` with `environment: { IMAGE: "{{ image }}" }`; extra vars `image`, `service_name`, `deploy_target` | ✅ |
| Image into deploy | Passed as extra var `image`; playbook sets env `IMAGE`; no templating, no in-repo edits | ✅ |
| App secrets | `env.enc` in `app/iac/`; Ansible decrypts to `.env` at deploy target; **same SOPS/age key** as infrastructure | ✅ |
| SHA format | 40 hex characters, no prefix | ✅ |
| Semver format | MAJOR.MINOR.PATCH, no `v` prefix | ✅ |
| Image reference | `{{registry_name}}/{{image_name}}:{{sha}}` | ✅ |
| Semantic tag conflict | Fail if semantic tag already exists | ✅ |
| Registry auth in task | SOPS-decrypted infra secrets; no decrypted file on disk | ✅ |
| validate-workspace | For `registry:deploy`: third arg = `'<WORKSPACE> <CONFIG_FILE_PATH>'`; validate parent dir of file is `iac`, ext `.yml` or `.yaml` | ⬜ |
| ansible:deploy | Greenfield; can be redefined to use same app/iac model | ✅ |
| Crane in registry:deploy | Include for functional completeness | ✅ |
| CI / OCI labels | Omitted for now (simplest) | ✅ |

---

## Versioning Strategy

* **Hybrid semantic + SHA:** SHA tag always present (from CI); semantic tag applied at promote time.
* **Semver:** Applied manually via deploy task; no `v` prefix.
* **Provisional:** Optional (e.g. `1.2.3-rc`) for QA.
* **Pruning:** SHA-only tags only; semantic tags retained. Manual; retention TBD.

---

## Design Rationale

* **App-owned deploy:** `app/iac/deploy.yml` and descriptors keep deploy logic with the app; IAC provides the workflow and wiring.
* **Single deploy task:** One command for promote, push, and deploy; explicit arguments; no hidden state.
* **SOPS:** One key for infra and app secrets keeps key management simple.
* **Crane:** Read-only, no automation of deletes or GC; human decides when to prune.
* **Convention over configuration:** Paths and targets derived from descriptor and app layout.

---

## Implementation Details

### Task File Structure

* **Task file:** `tasks/Taskfile.registry.yml`
* **Tasks:** `registry:deploy`; and the Crane read-only tasks `registry:list-images`, `registry:list-shas`, `registry:inspect-sha`, `registry:prune-candidates`.
* **Main task:** `registry:deploy` with `WORKSPACE` and `CONFIG_FILE_PATH`.

### Deployment Descriptor

* **Format:** YAML.
* **Location:** The file’s parent directory must be named exactly `iac`; the file extension must be `.yml` or `.yaml`. The basename is unrestricted.
* **Required fields:** `registry_name`, `image_name`, `sha`, `semver`, `service_name`.

### Compose File (`app/iac/docker-compose.yml`)

* **Convention:** Every app has `app/iac/docker-compose.yml`. It is a plain file: no Jinja, no templating.
* The service named `service_name` (from the deployment descriptor) must have `image: ${IMAGE}`. Docker Compose resolves `${IMAGE}` from the environment at runtime.
* IAC copies this file to `deploy_target/docker-compose.yml` on the server before running the app’s deploy playbook.

### App Deploy Playbook (`app/iac/deploy.yml`)

* **Type:** Ansible playbook.
* **Role:** Ensures server-side prerequisites, then runs `community.docker.docker_compose_v2` to deploy the app.
* **Extra vars from IAC:** `image`, `service_name`, `deploy_target`.
* **Responsibilities:** (1) Create any host directories required by volume mounts in `docker-compose.yml` (e.g. `{{ deploy_target }}/data`) before running `docker_compose_v2`. (2) Run `docker_compose_v2` with `project_src: "{{ deploy_target }}"` and `environment: { IMAGE: "{{ image }}" }` so that the copied `docker-compose.yml` resolves `${IMAGE}` to the promoted image. No templating; no in-repo file edits.

### IAC Ansible Integration

* **Playbook:** `ansible/deploy-app.yml`.
* **Responsibilities, in order:** (1) Decrypt infrastructure secrets; (2) decrypt `app_root/iac/env.enc` to `deploy_target/.env` if `app_root/iac/env.enc` exists; (3) copy `app_root/iac/docker-compose.yml` to `deploy_target/docker-compose.yml`; (4) run `app_root/iac/deploy.yml` with extra vars `image`, `service_name`, `deploy_target`.
* IAC obtains `app_root` and `deploy_target` from the descriptor path and the convention `deploy_target` = `/opt/giftfinder/` + basename of `app_root`.

### App Secrets (`env.enc`)

* **Location:** In the app’s `iac/` directory (e.g. `apps/hello/iac/env.enc`, `../MilledonAI/iac/env.enc`).
* **Target on server:** `.env` at the deploy target (e.g. `/opt/giftfinder/hello/.env`).
* **Decryption:** Ansible decrypts using **the same SOPS/age key** as `infrastructure-secrets.yml.enc` and writes `.env` at the deploy target. Only if `app_root/iac/env.enc` exists.

### SHA Format

* 40 hexadecimal characters; no `sha-` prefix.
* Task validates before any registry or Ansible operations.

### Semantic Version Format

* `MAJOR.MINOR.PATCH` (e.g. `1.2.3`); no `v` prefix.
* Task validates before any registry operations.

### Image Reference

* `{{registry_name}}/{{image_name}}:{{sha}}`. Example: `registry.rednaw.nl/rednaw/hello-world:f2f8d1dd6f2af2427baddc14334c2a13362696fd`

### Registry Auth in `registry:deploy`

* **Needed for:** pull (step 6) and push (step 8) from the machine running the task.
* **Source:** `secrets/infrastructure-secrets.yml.enc` (`registry_domain`, `registry_username`, `registry_password`).
* **Constraint:** Obtain via SOPS and a YAML-aware tool (e.g. `sops -d` with `yq` or `jq` to extract `registry_domain`, `registry_username`, `registry_password`). Feed credentials to `docker login` or Crane auth. Do not write decrypted YAML to disk.

### Error Handling

* Fail hard and early; clear messages.
* Validate: descriptor exists, is valid YAML, has required fields, correct SHA and semver format.
* Verify SHA-tagged image exists before promote.
* **Fail** if semantic tag already exists.

### Crane in `registry:deploy`

* After push, run read-only checks: confirm that `{{registry_name}}/{{image_name}}:{{semver}}` exists and its digest matches the digest of the SHA-tagged image that was pushed. Use `crane manifest` and `crane digest` to obtain and compare digests.

### Crane Tasks (Taskfile.registry.yml)

* **Tasks:** `registry:list-images`, `registry:list-shas`, `registry:inspect-sha`, `registry:prune-candidates`. Read-only: no tag changes or deletes. Auth via the same SOPS approach as `registry:deploy` (no decrypted secrets on disk).

### validate-workspace.sh

* **Extension for `registry:deploy`:** When the first argument is `registry` and the second is `deploy`, the third argument has the form `'<WORKSPACE> <CONFIG_FILE_PATH>'` (two tokens, space-separated). The script splits on the first space to obtain `WORKSPACE` and `CONFIG_FILE_PATH`.
* **Validation:** (1) `WORKSPACE` is `dev` or `prod`; (2) `CONFIG_FILE_PATH` exists; (3) the parent directory of `CONFIG_FILE_PATH` is named exactly `iac`; (4) the file extension is `.yml` or `.yaml`.
* **On success:** exit 0. The task uses the original third argument to obtain `CONFIG_FILE_PATH` (the substring after the first space). The script may print `WORKSPACE` to stdout for the task to consume, consistent with existing one-arg behaviour.
* **On failure:** exit 1, error on stderr.

---

## Actionable Next Steps

1. Implement **CI workflow**: full SHA tag + optional provisional; push only. ⬜  
2. Implement **`registry:deploy`** with `WORKSPACE` and `CONFIG_FILE_PATH`; all steps 1–10. ⬜  
3. **Ansible:** `ansible/deploy-app.yml` that decrypts infrastructure secrets; decrypts `app_root/iac/env.enc` to `deploy_target/.env` if present; copies `app_root/iac/docker-compose.yml` to `deploy_target/docker-compose.yml`; runs `app_root/iac/deploy.yml` with extra vars `image`, `service_name`, `deploy_target`. ⬜  
4. **App `iac/`:** For one app (e.g. `apps/hello`): `iac/docker-compose.yml` (plain, `image: ${IMAGE}` for the `service_name` service) and `iac/deploy.yml` (playbook that creates host dirs for volume mounts, then runs `docker_compose_v2` with `environment: { IMAGE: "{{ image }}" }`). ⬜  
5. **Extend `validate-workspace.sh`** for two-arg case. ⬜  
6. **Crane:** Inspection in `registry:deploy` plus tasks `registry:list-images`, `registry:list-shas`, `registry:inspect-sha`, `registry:prune-candidates`. ⬜  
7. **Include** `tasks/Taskfile.registry.yml` from root `Taskfile.yml`. ⬜  

---

## Notes

* `CONFIG_FILE_PATH` is the deployment descriptor; the name “deployment descriptor” is used in the human doc.
* Semantic tag conflict → task fails (no overwrites).
* `ansible:deploy` can be redefined to follow the same app/iac and convention-over-configuration model; no backward compatibility required.
* This spec and **application-deployment.md** are the authoritative pair; keep them in sync.
