# Platform Parameterization: Design Document

## Purpose

Make the `iac` repository a **reusable library** that can be used by multiple organizations (rednaw, milledoni, and others) to deploy infrastructure and applications, without requiring forks or organization-specific code in the library.

## Current State

The `iac` repository currently has hardcoded values that tie it to specific domains and organizations:
- Domain names (`rednaw.nl`) hardcoded in multiple places
- Terraform Cloud organization (`rednaw`) hardcoded in backend config
- Hostname patterns (`dev.rednaw.nl`, `prod.rednaw.nl`) hardcoded
- Registry domains, SSL certificate domains, etc. all hardcoded

This prevents the platform from being used by multiple organizations without forking.

## Intended Capability

### Library Model

**`iac` repository = Pure library**
- Contains only code (Terraform, Ansible, Taskfiles, scripts)
- Contains example/template files (no real secrets or config)
- Zero organization-specific configuration
- Zero real secrets

**Consumer projects = Own their config and secrets**
- Infrastructure projects (e.g., `rednaw/infra/`): Own infrastructure config and secrets
- Application projects (e.g., `rednaw/hello-world/`): Own application config and secrets
- Call `iac` library via Taskfile includes (already working pattern)

### What Gets Parameterized

**Organization-specific configuration** (moved to consumer projects):
- `iac-config.yml`: `base_domain`, `terraform_cloud_organization`
- Everything else uses conventions (hostnames, registry domains, SSL certs, etc.)

**Infrastructure secrets** (moved to consumer projects):
- `secrets/infrastructure-secrets.yml`: Hetzner token, SSH keys, registry credentials, etc.
- Lives alongside `iac-config.yml`:
  - If separate infrastructure project: `rednaw/infra/secrets/infrastructure-secrets.yml`
  - If standalone app project: `rednaw/hello-world/secrets/infrastructure-secrets.yml`

**Application secrets** (already in app projects):
- `secrets.yml`: API keys, database passwords, etc.
- Already lives in application projects (no change needed)

**SOPS keys** (moved to consumer projects):
- `secrets/sops-key-*.pub`: Consumer's team public keys
- `.sops.yaml`: SOPS configuration referencing consumer's keys

### Interface

**Current pattern (already working):**
```yaml
# Consumer project Taskfile.yml
includes:
  iac:
    taskfile: ../iac/tasks/Taskfile.app.yml

# Consumer calls:
task iac:deploy -- dev abc1234
```

**After parameterization:**
- Same interface - consumer includes `iac` Taskfiles
- Consumer sets vars: `IAC_CONFIG_FILE`, `INFRASTRUCTURE_SECRETS_FILE`
- `iac` library reads config/secrets from provided paths
- No change to consumer workflow

### Conventions (No Configuration Needed)

- Hostnames: `{env}.{base_domain}` (e.g., `dev.rednaw.nl`)
- Registry domain: `registry.{base_domain}` (e.g., `registry.rednaw.nl`)
- SSL certificate domains: Auto-generated from `base_domain` and `env`
- Workspace prefix: `platform-` (fixed)
- Server names: `platform-{env}` (fixed)
- Firewall names: `platform-firewall-{env}` (fixed)

## Key Decisions

### ✅ Decided

1. **Library model**: `iac` is a library, consumers own config/secrets
2. **Convention over configuration**: Minimal config (only `base_domain` and `terraform_cloud_organization`)
3. **Taskfile includes**: Use existing pattern (already working)
4. **No backwards compatibility**: No real clients yet, can make breaking changes
5. **Two types of secrets**: Infrastructure secrets (infra project) vs application secrets (app project)
6. **SOPS keys**: Live in consumer projects, not library

### ❓ Open Questions

1. **Terraform backend organization**
   - **Question**: How to handle Terraform Cloud organization in backend config?
   - **Options**:
     - A: Generate `terraform/versions.tf` or backend config from consumer's `iac-config.yml` before `terraform init`
     - B: Use `-backend-config` file/flag with organization from consumer config
     - C: Each consumer has their own `terraform/` directory with hardcoded org
   - **Recommendation**: Option B (`-backend-config`) - cleanest, supports library model

2. **Consumer project structure**
   - **Question**: Should infrastructure and application projects be separate, or can apps be standalone?
   - **Options**:
     - A: Separate infra project (`rednaw/infra/`) + app projects reference it
     - B: App projects can be standalone (have own `iac-config.yml` and `secrets/infrastructure-secrets.yml`)
     - C: Both supported (flexible)
   - **Recommendation**: Option C (both supported) - maximum flexibility
   - **Clarification**: Infrastructure secrets always live alongside `iac-config.yml` in the same project (no "shared location" concept)

3. **Config/secrets path resolution**
   - **Question**: How should `iac` library resolve paths to config/secrets?
   - **Options**:
     - A: Always require explicit paths (vars/env vars/CLI flags)
     - B: Auto-detect relative to consumer project root (convention: `iac-config.yml` in project root)
     - C: Both (explicit paths override auto-detection)
   - **Recommendation**: Option C (both) - explicit for flexibility, auto-detect for convenience

4. **Inventory files**
   - **Question**: Should Ansible inventory files be generated from config or remain static?
   - **Options**:
     - A: Generate from `iac-config.yml` (`base_domain` + convention)
     - B: Keep static files, validate they match config
     - C: Generate on-demand, don't commit
   - **Recommendation**: Option A (generate) - single source of truth

5. **GitHub workflows in `iac` repo**
   - **Question**: Are workflows library-level (testing the library) or consumer-level (deploying infrastructure)?
   - **Current**: Workflows test the library (static code analysis, etc.)
   - **Question**: Should consumer-specific workflows (like image promotion) live in consumer projects?
   - **Recommendation**: Keep library testing workflows in `iac`, move deployment workflows to consumers

6. **Application secrets path**
   - **Question**: Should application secrets path be configurable or always `{{.APP_ROOT}}/secrets.yml`?
   - **Current**: Auto-detected as `app_root/secrets.yml`
   - **Recommendation**: Keep auto-detection, allow override via var if needed

## Implementation Approach

1. **Move secrets/config out of `iac` repo**
   - `secrets/infrastructure-secrets.yml` → `secrets/infrastructure-secrets.example.yml`
   - Move SOPS keys to examples or remove
   - Create `iac-config.yml.example` template

2. **Update all code to accept paths**
   - Terraform: Accept `secrets_file` path as variable
   - Ansible: Accept `iac_config_file` and `infrastructure_secrets_file` paths
   - Taskfiles: Accept paths via vars/env vars
   - Scripts: Accept paths as arguments

3. **Remove all hardcoded values**
   - Domain names → read from `iac-config.yml`
   - Hostnames → generate from `base_domain` + convention
   - Registry domains → generate from `base_domain` + convention
   - Terraform Cloud org → read from `iac-config.yml` or backend config

4. **Update consumer projects**
   - Create `iac-config.yml` with org/domain config
   - Create `secrets/infrastructure-secrets.yml` with real secrets
   - Set vars in `Taskfile.yml` pointing to config/secrets

## Success Criteria

- ✅ `iac` repo has zero organization-specific config or secrets
- ✅ Multiple organizations can use `iac` library without forking
- ✅ Consumer projects own their config and secrets
- ✅ Interface remains simple (Taskfile includes, minimal vars)
- ✅ Conventions minimize configuration needed

## Next Steps

1. **Answer open questions** (especially Terraform backend org handling)
2. **Create example consumer project** structure
3. **Implement parameterization** (one component at a time)
4. **Test with hello-world** as first consumer
5. **Document consumer setup** process
