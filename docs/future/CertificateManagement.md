# TLS Certificate Management Strategy for nginx with Ansible

---

## 1. Problem Statement

TLS management must satisfy the following constraints:

* Works with nginx and HTTP-01 challenges
* Supports SAN certificates
* Is safe under repeated Ansible runs
* Avoids silent nginx misconfiguration
* Provides predictable certificate paths
* Minimizes operational surprises

Historically, Certbot CLI was used, but this introduced:

* ordering-sensitive Ansible logic
* fragile fact reuse
* certificate name ambiguity
* hard-to-debug failures

---

## 2. Considered Options

Two mutually exclusive solutions were designed and evaluated:

1. **Certbot-based deterministic design**
2. **Native ACME-module-based design**

These are **alternatives**, not layers.

> A host must use **one or the other**, never both.

---

## 3. Option A: Deterministic Certbot-Based Design

### Summary

This option keeps Certbot CLI but removes its most common failure modes by enforcing deterministic Ansible behavior.

Certbot remains the certificate authority client; Ansible orchestrates safely around it.

---

### Key Characteristics

* Uses `certbot certonly`
* Explicit `--cert-name`
* SAN expansion via `--expand`
* Certificate state detected via `stat`
* nginx HTTP and HTTPS configs separated
* No conditional logic inside templates

---

### Design Principles

1. Certbot owns certificate lifecycle
2. Ansible only *detects* cert state
3. nginx templates are unconditional
4. Enablement is task-driven, not Jinja-driven
5. Certificate existence is always re-evaluated

---

### Operational Flow

```
Ansible
 ├── Deploy nginx HTTP config
 ├── Run Certbot (certonly)
 ├── Re-check certificate existence
 ├── Deploy nginx HTTPS config
 └── Reload nginx
```

---

### Strengths

* Minimal change from existing setup
* Compatible with certbot.timer
* Easy to reason about for operators
* Low migration cost

---

### Weaknesses

* Still depends on CLI behavior
* Partial idempotency (Certbot-specific)
* Shell usage remains
* More moving parts long-term

---

## 4. Option B: Native ACME Module Design

### Summary

This option replaces Certbot entirely with native ACME protocol support via Ansible modules.

Ansible becomes the single source of truth for certificate state.

---

### Key Characteristics

* Uses `community.crypto.acme_certificate`
* No shell or command usage
* Declarative private key, CSR, and cert
* SANs managed via CSR regeneration
* Certificate renewal handled by playbook re-run
* No Certbot installation or timers

---

### Design Principles

1. Ansible owns all TLS state
2. ACME is a pure external authority
3. Certificate identity is explicit
4. Renewal is a side-effect of idempotency
5. No background services required

---

### Operational Flow

```
Ansible
 ├── Deploy nginx HTTP config
 ├── Ensure ACME account key
 ├── Ensure cert private key
 ├── Generate CSR with SANs
 ├── Obtain / renew certificate
 ├── Deploy nginx HTTPS config
 └── Reload nginx
```

---

### Strengths

* Fully idempotent
* No CLI quirks
* No implicit state
* Clean long-term maintenance
* Predictable behavior under automation

---

### Weaknesses

* Moderate refactor required
* Requires ACME module familiarity
* Removes certbot.timer model
* Slightly higher upfront complexity

---

## 5. Comparison Summary

| Aspect                | Certbot Design | ACME Design    |
| --------------------- | -------------- | -------------- |
| Cert client           | Certbot CLI    | Native ACME    |
| Shell usage           | Yes            | No             |
| Idempotency           | Partial        | Full           |
| SAN handling          | `--expand`     | CSR-based      |
| Renewal model         | certbot.timer  | Playbook rerun |
| Migration cost        | Low            | Medium         |
| Long-term cleanliness | Good           | Excellent      |

---

## 6. Decision Guidance

### Use the **Certbot-Based Design** when:

* Existing infrastructure already uses Certbot
* Minimal change is required now
* Operational familiarity is important
* Backlog capacity is limited

### Use the **ACME-Based Design** when:

* Greenfield or major refactor is acceptable
* Full idempotency is required
* Shell usage must be eliminated
* Long-term maintainability is prioritized

