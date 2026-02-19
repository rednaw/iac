# Documentation Strategy

This document defines how we structure and write documentation so it stays consistent, findable, and useful. Use it when adding or refactoring docs.

**Context:** There is one sequence: create the platform (secrets, Terraform, Ansible, server exists), then get access and operate (SOPS key, SSH, devcontainer, deploy, troubleshoot, Traefik, registry, etc.). You either **create the project** (New project, then you operate) or **join** when the project already exists (Joining). Docs are organized by where you enter: New project or Join an existing project.

---

## 1. New project and Join an existing project

**New project** = You create the platform (SOPS, secrets file, Terraform Cloud, Terraform, Ansible; server and infra exist), then add your app and operate. **Join an existing project** = The project already exists; you get access (SOPS key, SSH), then operate and deploy. Everyone ends up operating; the only choice is whether you create first or join.

| Entry point | What you do | Doc | Then |
|-------------|-------------|-----|------|
| **New project** | You create the server and platform, then add your app and operate. | [Onboarding](onboarding.md) → New project path | New project, Launch devcontainer, Application deployment, Secrets |
| **Join an existing project** | The project already exists. You get access (SOPS key, SSH), then operate and deploy. | [Joining](joining.md) | Application deployment, Troubleshooting, Traefik, Registry, Monitoring |

**Implications:**

- **One entry point per path.** Don't mix "new project" and "join" on one page without clear labels. The index is where you choose; from there, New project → Onboarding (New project path); Join an existing project → Onboarding (Join path).
- When a doc serves both (e.g. Application deployment), use clear section labels (e.g. "If you created the project", "If you joined").
- Navigation offers **two entry points** on the index: "New project" and "Join an existing project".

---

## 2. Document types

We use four doc types. Each has a consistent role and a standard structure where applicable.

### 2.1 Getting started / Tutorial

**Purpose:** Get someone from zero to a working outcome (e.g. "app running", "able to deploy", "able to operate server").

**Who it's for:** Depends on the doc (e.g. Joining = join only; New project / Onboarding = create then operate).

**Structure:**

- **Which path** — clear in the opening (e.g. first paragraph).
- **Prerequisites** (if any).
- **Outcome** ("When done, you will...").
- **Steps** in order (numbered). One main path; optional "Variation: ..." for alternatives.
- **Next steps** (links to relevant reference or other tutorials).

**Examples:** "New project", "Joining", "First deployment from the IAC devcontainer".

---

### 2.2 Reference

**Purpose:** Authoritative, lookup information: commands, files, config keys, locations.

**Who it's for:** Depends on the topic (join for infra ops; new project for app config when you're adding your app).

**Structure:**

- **Which path** — clear in the opening.
- **What this is** (one short paragraph).
- **Sections by topic** (e.g. Commands, File locations, Config keys). Prefer tables and lists over long prose.
- **Related** (links to tutorials or concepts that use this reference).

**Examples:** "Secrets: file locations and editing", "Registry: auth and commands", "Traefik: labels and config files".

---

### 2.3 Concept / Architecture

**Purpose:** Explain "how it works" and "why it's designed this way" — no step-by-step, no copy-paste runbook.

**Who it's for:** Depends on scope (either path).

**Structure:**

- **Which path** — clear in the opening.
- **Summary** (2–4 sentences).
- **Diagrams** where helpful (e.g. Mermaid).
- **Sections** by concept (e.g. Data flow, Security model, Design decisions).
- **See also** (links to tutorials and reference that implement this).

**Examples:** "Deployment pipeline (concept)", "Compose layout and app contract", "Monitoring and observability".

---

### 2.4 Operations / Runbook

**Purpose:** How to perform recurring or one-off operational tasks (restart service, check status, unban IP, deploy, upgrade).

**Who it's for:** Join (operations); new project for app-only tasks like deploy.

**Structure:**

- **Which path** — clear in the opening.
- **Task name** as H2 (e.g. "Restart Traefik", "Deploy an app version").
- For each task: **When** (optional), **How** (commands or steps), **Verify** (optional one-liner).
- **Troubleshooting** (short table or list) or link to main Troubleshooting doc.

**Examples:** "Traefik operations", "Registry operations", "Deployment operations", "Server troubleshooting".

---

## 3. Style and mechanics

### 3.1 Easy reading, not corporate

Structure is for clarity; the prose should stay human and easy to read.

- **Plain language.** Say it simply. Prefer "use" over "utilize", "get" over "obtain", "run" over "execute". No buzzwords (leverage, synergy, stakeholder, enablement, solutioning).
- **Short sentences.** One idea per sentence when you can. Break up long paragraphs.
- **You and we.** Address the reader as "you". "We" is fine when it means "this project" or "we do it this way". Avoid the passive when the active is clearer ("Ansible copies the file" not "The file is copied by Ansible").
- **Concrete over abstract.** "Add your app's hostname to the Traefik label" rather than "Configure the routing endpoint for your service". Examples and copy-paste snippets help more than long explanations.
- **Scannable but readable.** Headings and lists make docs scannable; the text under them should still read well if someone reads top to bottom. No walls of bullets where a short paragraph would be clearer.

The goal is: someone can find the right doc, follow the steps or look up the detail, and not feel they're reading a vendor manual.

### 3.2 Mechanics

- **Every doc:** Starts with a breadcrumb to the doc index (e.g. `[**<---**](README.md)`). Make it clear which path (new project or join) the doc is for in the opening (e.g. first paragraph or section headings)—no need for a formal "Audience:" label.
- **Tone:** Use "you" and imperative for instructions ("Run ...", "Add ..."). Use present tense for facts ("The registry runs on ...").
- **Level:** One main level per doc (or per major section). If a section is "for experts", say so (e.g. "Implementation details (if you joined)").
- **Cross-links:** Prefer "See [Doc](link) for ..." over "see above" or vague "see documentation". Link to the specific section when it helps.
- **Code and commands:** Use fenced blocks with language; show full commands (e.g. `task app:deploy -- dev 706c88c`) so they can be copied.
- **Rednaw-specific names:** Prefer parameterized wording (e.g. "observe.&lt;base_domain&gt;", "registry.&lt;base_domain&gt;") where we already have a convention; where we don't, use a single placeholder (e.g. "&lt;base_domain&gt;") and one real example (e.g. rednaw.nl) in parentheses.

---

## 4. Proposed documentation structure

Reorganize the doc set so that:

1. **Navigation is by entry point** (New project vs Join an existing project), not a single flat list.
2. **One concern per doc (or per clearly labeled section)** so we can link and refactor without mixing paths.
3. **Tutorials are short and linear**; reference and runbooks are the place for "everything about X".

### 4.1 Top-level index (`docs/README.md`)

The index is the source of truth for "what goes where". It has: a short intro (create the platform, then operate—or join), two sections—"New project" and "Join an existing project"—each with a blurb and link list, plus Reference and Other. **When you change the index, you don't need to update this strategy doc**—the strategy describes the shape (two entry points + reference), not the exact link list. See `docs/README.md` for the current index.

### 4.2 Suggested file layout (after refactor)

Not a final file list—more a target shape. Renames and splits can be done incrementally.

| Current | Proposed role | Path |
|---------|----------------|------|
| `onboarding.md` | Entry for both paths: diagram, New project sequence, Join existing project sequence. | Both |
| `new-project.md` | Tutorial: create the platform (bootstrap server from scratch). | New project |
| `joining.md` | Tutorial: join — get access (SOPS key, SSH), then operate. | Join |
| `launch-devcontainer.md` | Shared: how to open the workspace and start the devcontainer; what happens on startup (decrypt, credentials). Linked from Onboarding, New project, Joining. | Both |
| `application-deployment.md` | Commands and app mount for both; Application Configuration for new project; Deployment Records and Implementation Details for join. Section labels: "If you created the project", "If you joined". | Both |
| `secrets.md` | Reference (files, editing, SOPS) + short "First-time setup" / "Add a new person" as tutorials or sections. | Both |
| `registry.md` | Reference + operations. New project only needs "auth is automatic in devcontainer." | Both |
| `traefik.md` | Reference (config, labels); Operations (restart, logs, dashboard); Adding an app (copy-paste for new project). | Both |
| `monitoring.md` | What's there (OpenObserve, dashboards, logs), how to access. | Join |
| `private.md` | Reference: local config files. Move "Known security risks" to separate doc or short section. | Join |
| `troubleshooting.md` | Runbook-style: common failures, cause, fix. One place for connection, host key, secrets, deploy, registry. | Both |
| `technologies.md` | Keep as "Tools and technologies" reference (link list). | Both |
| `design-compose-files.md` | Concept: compose layout (single full-stack compose, devcontainer build). Useful when adding your app. | New project |
| `upgrading.md` | Reference + short operations (Renovate, PRs). | Join |
| `remote-vscode.md` | Short runbook: Run VS Code/Cursor on the server. | Join |
| `code-analysis.md` | Reference: what runs, when (CI), how to run locally. | Join |
| `CONTRIBUTING.md` | Unchanged; linked from index. | Contributors |

### 4.3 Migration approach

1. **Do not rewrite everything at once.** Apply the strategy to one area at a time (e.g. "Traefik", "Secrets", "Deployment").
2. **For each doc (or group):**
   - Assign **path** (new project, join, or both) and **doc type** (tutorial, reference, concept, runbook).
   - Make clear which path the doc is for in the opening and ensure **structure** matches the type (see §2).
   - Split only if a doc is long and serves both paths at different depths; otherwise, add clear section headings ("If you created the project", "If you joined", "Reference").
3. **Update `docs/README.md`** first to the new "New project / Join an existing project + reference" index, then adjust links as we refactor each doc.
4. **Backlog:** Keep "documentation TLC" in Backlog; close items as we apply this strategy (e.g. "Traefik docs: section labels by entry point", "application-deployment: section labels by entry point").

---

## 5. Summary

| Principle | Action |
|-----------|--------|
| **Paths** | One sequence: create the platform, then get access and operate. Two entry points: New project or Join an existing project. Make clear which path each doc is for. |
| **Doc types** | Getting started (tutorial), Reference, Concept/Architecture, Operations/Runbook. Use consistent structure per type. |
| **Structure** | Index by entry point ("New project" vs "Join an existing project") + reference by topic. Entry docs short; one main concern per doc or per labeled section. |
| **Style** | Breadcrumb, clear which path the doc is for in the opening, clear level per section, cross-links, copy-paste-friendly commands. |
| **Tone** | Easy reading, not corporate: plain language, short sentences, you/we, concrete examples. No buzzwords; no vendor-manual feel. |
| **Migration** | Incremental: index first, then refactor by area; split only when necessary. |

This strategy should remove fragmentation, align style, separate high-level from low-level by doc type and section, and make it clear which doc to open depending on whether you're creating a new project or joining.

---

## 6. Keeping this document in sync

- **Use straight quotes** in this file (`"` and `'`), not curly/smart quotes. That way search-and-replace and simple editors work reliably.
- **New project** and **Join an existing project** are the two entry points (defined in §1); when you change the wording, search the whole doc for the old phrasing and update every occurrence.
- **§4.2 file layout** is a snapshot of roles and path per doc. Update it when you add a doc, remove one, or change which path a doc serves. It's okay if the table lags slightly; the index (README.md) is what readers see.
- **Don't duplicate the index** in §4.1. The index lives in `docs/README.md`; this doc only describes its shape.
