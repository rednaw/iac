## State Management – Options and Trade-offs

### Why This Matters

**State management is a fundamental requirement of all Infrastructure-as-Code tools** (Terraform, Pulumi, CloudFormation, etc.), not just Terraform. Every IaC tool needs to track:

- **Resource IDs**: Unique identifiers assigned by cloud providers
- **Resource attributes**: Current values like IP addresses, configurations
- **Dependencies**: Relationships between resources
- **Computed values**: Values learned after resource creation

**The problem with local state**: With a team of developers, each person having their own local state file creates challenges:

1. **State synchronization**: Changes by one person aren't visible to the other
2. **Concurrent modifications**: Simultaneous operations can conflict
3. **State loss**: Lost state files require recovery via import
4. **No shared history**: No central record of infrastructure evolution

**The solution**: Different backend options address these problems:
- **Remote backends** provide shared state and automatic locking
- **Version control** (Git + SOPS) provides backup and history
- **Local state** keeps things simple but requires manual coordination

**Important security consideration**: Terraform state files may contain sensitive information such as API tokens, passwords, private keys, and other secrets that are used or generated during resource creation. Always treat state files as sensitive data and ensure they are stored securely and access is restricted appropriately.

This document compares options for this project to help make informed decisions.

---

### 1. Terraform Cloud (Remote Backend) ✅ **RECOMMENDED**

**Description**
- Terraform state is stored in HashiCorp's Terraform Cloud.
- **This is the recommended approach** for team collaboration.

**Why This Is Preferred**

Terraform Cloud solves all the fundamental problems of state management:

1. **Automatic state locking**: Prevents concurrent `terraform apply` operations from conflicting. No manual coordination needed.
2. **Shared state**: All team members use the same state file automatically. No synchronization issues.
3. **State history**: Complete audit trail of all state changes in the Terraform Cloud UI.
4. **Zero maintenance**: State is managed automatically. No files to backup, no recovery procedures.
5. **Free tier**: Covers small teams and infrequent changes at no cost.
6. **Team collaboration**: Multiple developers can work on infrastructure without conflicts.

**Pros**
- **Free tier** covers this project's needs
- **State locking** out of the box (prevents concurrent applies)
- **Centralized state** with history
- No self-managed storage or additional infra
- **Automatic**: State is managed transparently
- **Team-ready**: Works seamlessly with multiple developers

**Cons**
- **External service**: Requires team accounts and organization setup
- **Token management**: Each dev needs a Terraform Cloud API token (stored locally, not in Git)
- **Vendor dependence**: Relies on HashiCorp's uptime and policies

**Setup**
- Organization: `milledoni`
- Workspaces: `giftfinder-dev`, `giftfinder-prod` (separate workspaces per environment)
- Backend prefix: `giftfinder-` (matches all workspaces with this prefix)
- Authentication: Via `terraform login` or manual token in `~/.terraform.d/credentials.tfrc.json`

**When this is a good fit**
- Any team with 2+ developers (recommended for all team setups)
- Want automatic locking without manual coordination
- Want state history and audit trail
- Comfortable with external service dependency

**Status**: ✅ **Currently active and recommended**

---

### 2. Local State

**Description**
- State file (`iac/terraform/terraform.tfstate`) lives only on each developer's machine.
- File is gitignored; not shared via Git.

**Pros**
- **Simple**: No extra services or configuration.
- **Fast**: Local file I/O, no network latency.
- **No external dependency**: Everything runs with just Terraform + Hetzner.
- **Good enough for small/infrequent changes** when the team coordinates.

**Cons**
- **Per-developer state**: Each dev has their own copy; can get out of sync.
- **No locking**: Two `terraform apply` runs in parallel can conflict.
- **Recovery requires imports** on a fresh clone (need to re-import existing resources by ID).
- **No shared history**: No central record of state evolution.

**Risk profile (team of 2, private repo)**
- With coordination ("I'm applying now, don't touch"), risk is **moderate but acceptable**.
- State can drift from actual infrastructure if manual changes are made.
- "Catastrophic" loss (fresh clone, disk loss) is **recoverable** via `terraform import` using Hetzner `hcloud` CLI / console, since all desired resources are defined in code.

**When this is a good fit**
- Solo developer (no team collaboration needed)
- Very infrequent infrastructure changes
- Team is comfortable with strict coordination requirements
- Want to avoid any external dependencies

**Status**: ❌ Not recommended for teams

---

### 3. Local State in Git, Encrypted with SOPS

**Description**
- After each `terraform apply`, encrypt `terraform.tfstate` to `terraform.tfstate.enc` using SOPS and commit the encrypted file to Git.
- Decrypt before running Terraform; re-encrypt after.

**Pros**
- **Backup & history**: Git becomes the source of truth for state; history is versioned.
- **Security**: Encrypted with SOPS; repo is private, and encrypted files are safe to commit.
- **Team access**: Any dev can clone the repo, decrypt, and get the exact shared state.
- **No external service**: Everything stays in your Git repository.

**Cons**
- **No locking**: Git doesn't prevent concurrent edits; two people can commit conflicting state.
- **Merge conflicts**: Encrypted JSON blobs are hard to merge; conflict resolution is painful and error-prone.
- **Workflow friction**: Requires a disciplined "decrypt → apply → encrypt → commit" cycle.
- **State noise in history**: Frequent commits containing only state changes.

**Risk profile (team of 2, private repo)**
- Security is fine (private repo + SOPS).
- **Main risk is operational**: Conflicting updates and merge conflicts, not data exposure.
- Requires strong discipline: only one person applies at a time, and state is always re-encrypted + committed immediately after.

**When this is a good fit**
- Want **central, versioned state** but absolutely cannot use external services
- Team is highly disciplined about Terraform workflows
- Small number of resources and infrequent changes (keeps conflicts rare)
- Willing to accept merge conflict risks

**Status**: ⚠️ Not recommended (use Terraform Cloud instead)

---

### 4. Remote State in Object Storage (e.g., Hetzner Object Storage)

**Description**
- Use Terraform's `s3` backend pointed at an S3-compatible bucket (Hetzner Object Storage).
- State is stored centrally in the bucket.

**Pros**
- **Shared state**: All devs use the same state file.
- **Simple mental model**: "State lives in the bucket."
- **Works with S3-compatible APIs**.

**Cons (specific to Hetzner Object Storage for this project)**
- **Cost floor**: Base price ~€4.99/month regardless of usage; too high for this use case.
- **No native locking**: Terraform's S3 backend normally pairs with DynamoDB for locks; Hetzner doesn't have that.
- **Extra complexity**: Need to manage bucket, credentials, endpoints.
- **Still requires coordination**: Without locking, concurrent applies can still conflict.

**Risk profile**
- Technically solid, but **financially overkill** for this project.
- Still no strong state locking unless you add more infrastructure.
- More expensive than Terraform Cloud (which is free) with fewer features.

**When this is a good fit**
- Bigger infra budget and/or already using Hetzner Object Storage
- Willing to pay the monthly base fee
- Need self-hosted solution (can't use Terraform Cloud)

**Status**: ❌ Not recommended (too expensive, no locking, Terraform Cloud is better)

---

### Summary Table

| Option                          | Cost        | Locking | Shared State | Complexity | Recommendation |
|---------------------------------|------------|--------|-------------|------------|----------------|
| **Terraform Cloud backend**     | Free (basic) | ✅ Yes | ✅ Yes      | Low        | ✅ **RECOMMENDED** |
| Local state                     | Free       | ❌ No  | ❌ Per-dev  | Low        | ❌ Not for teams |
| Local state + Git+SOPS          | Free       | ❌ No  | ✅ Yes      | Medium     | ⚠️ Not recommended |
| Hetzner Object Storage backend  | ≥ €4.99/mo | ❌ No  | ✅ Yes      | Medium     | ❌ Too expensive |

---

### Current Implementation

**Active**: Terraform Cloud backend
- **Organization**: `milledoni`
- **Workspaces**: `giftfinder-dev`, `giftfinder-prod` (separate state per environment)
- **Backend configuration**: Uses prefix `giftfinder-` to match all workspaces
- **State location**: Terraform Cloud (remote, separate state per workspace)
- **Locking**: Automatic (prevents concurrent applies)
- **Team access**: All team members with Terraform Cloud accounts can access

**Benefits realized**:
- ✅ Shared state across team
- ✅ Automatic locking (no coordination needed)
- ✅ State history in Terraform Cloud UI
- ✅ No local state files to manage
- ✅ Free tier covers our needs

**For team members**:
1. Create Terraform Cloud account
2. Get added to `milledoni` organization
3. Run `terraform login` to authenticate
4. Create workspaces in Terraform Cloud: `giftfinder-dev` and `giftfinder-prod` (one-time setup)
5. Run `task terraform:init -- dev` or `task terraform:init -- prod` (will connect to remote backend automatically)

---

### Why Terraform Cloud Over Other Options

**vs. Local State**: 
- Automatic locking eliminates coordination overhead
- Shared state prevents synchronization issues
- State history provides audit trail

**vs. Git + SOPS**:
- No merge conflicts (automatic locking)
- Simpler workflow (no encrypt/decrypt cycle)
- Better conflict resolution

**vs. Object Storage**:
- Free vs. €4.99/month
- Built-in locking vs. no locking
- Managed service vs. self-managed

**Conclusion**: Terraform Cloud provides the best balance of features, cost, and simplicity for team collaboration.
