# VPN / platform split

Split today’s coupled `iac` so **platform** (public, Western ops) and **VPN** (private, China-travel break-glass) are independent in **git** and **Hetzner**. Goal: burned-IP renew from mainland without eSIM or the hotel laptop, via a private-repo workflow, without credentials that can touch `rednaw.nl`.

Trip ops / REALITY / clients stay in [vpn-travel-china.md](vpn-travel-china.md) + manual. This plan is only the structural split and CI renew control plane.

**Not legal advice.**

---

## Decided

| | |
|--|--|
| Priority | **Security, safety, and blast-radius reduction beat convenience** on every Decide. If two options both work, pick the smaller blast radius. Trip UX is secondary. |
| Simplicity | New VPN stack: **as few moving parts as possible.** Prefer fewer vendors, fewer tokens, fewer runtimes. Reject optional complexity. |
| No Terraform for VPN | New VPN stack uses **no Terraform and no TFC**. Provision / wipe / renew = `hcloud` (CLI or API) scripts + bootstrap for Docker/Xray. |
| VPN secrets | **GitHub Actions secrets only** (VPN Hetzner token, `vpn_*` for link emit). No age/SOPS, no TFC, no TF state backend creds. |
| Goal | Platform and VPN are separate products: separate git repos, separate Hetzner Cloud **projects**, separate API tokens. |
| Platform repo | `iac` is **already public**. It stays the Western platform project. After EU excision it must contain **no** VPN automation, break-glass, or VPN credentials in tree/CI. |
| Fact (today) | Live trip VPN **automation already lives in public `iac`** (`terraform/vpn/`, tasks, scripts, plans/ideas). Secrets stay in private `secrets` / TFC — but the *recipe* is public. New private VPN repo exists to end that. |
| VPN repo | New **private** git repo under the **existing GitHub account/org**: provision/configure + renew-IP workflow. Map in `rednaw-map` as a private sibling. |
| Hetzner customer | **First iteration: same Hetzner customer account** as platform. Isolation = separate Cloud **project** + project-bound token only. |
| Hetzner API | Two Cloud projects; tokens are project-bound. VPN CI uses a **VPN-project-only** token. Never a shared `hcloud_token` across platform + VPN. |
| Phase 2 (later) | After the new stack is proven: revisit **dedicated GitHub account/org** and **dedicated Hetzner customer** for stronger abuse/ToS isolation. Not in this plan’s Do. |
| Blast radius | Compromise of VPN repo / its GH secrets / its CI must not yield: platform Hetzner token, platform TFC, platform age key, platform SSH, TransIP, or ability to mutate `rednaw.nl`. |
| CI hygiene | No `pull_request` runners with secrets; no fork PRs; minimal secret set; no platform secrets. Friends must **not** need permission to edit workflows/scripts (that ≈ Hetzner VPN token theft). |
| Credentials in git | Never commit `vless://`, UUID, REALITY keys, or tokens to git history (including “private repo file” check-ins). |
| Renew semantics | Disk/Xray kept; emit new address to sticky issue. **Not** Hetzner delete-and-recreate on the same primary-IP object (that recycles the burned address). |
| Renew algorithm | Live `iac` (`scripts/vpn-renew-ip.sh`): create → if denylisted **hold** (no delete mid-loop) → repeat until fresh → move → **delete old + all holds**. |
| Burn history (iac now) | Local denylist `.vpn-burned-ips` (gitignored). Hold is temporary during create only (breaks sticky recycle); no long-term €0.50 holds. |
| Friend renew | Two trusted Chinese friends must be able to **trigger renew themselves** (no laptop/eSIM of yours). They are clients + renew operators, not platform admins. |
| IssueOps | **One dedicated sticky issue** in the private VPN repo is the control panel. Friends: **Read/Triage** only (no Write / no workflow edits). |
| Trigger | Allowlisted friend (or you) posts a **comment** on that issue → Actions renew job runs (`concurrency: 1`). Ignore comments from others; optional magic word e.g. `/renew` to avoid accidental chatter. |
| Publish link | Job **updates that issue’s body** with the current `vless://` + **generated-at** timestamp. No git commit, no artifact required. (Issue body is durable credential storage for repo readers — accepted for phone UX.) |
| Client UUID | **One shared UUID** for Western travellers + two friends (simplicity). Leak ⇒ rotate for everyone. Not a GFW concern. |
| Trip continuity | **Current `iac`-linked VPN stays the live exit for the whole trip.** Do not migrate, cut over, or decommission it while travelling. |
| Parallel build | **Build the new private VPN stack while in China**, using the current `iac` VPN (OneXray) as the work path to GitHub / Hetzner. |
| Decommission | Tear down the `iac`-linked VPN (and shared-token coupling) **when back in the EU** — not before. |
| Trip plan | [vpn-travel-china.md](vpn-travel-china.md) remains the trip Decided/Do for the live `iac` VPN until EU decommission; then retarget to the private VPN repo. |

---

## Decide

None.

---

## Do

### 0. Inventory current coupling (can start now)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — list what must move or die in `iac`: `terraform/vpn/`, `ansible` vpn playbook/role, `tasks/Taskfile.vpn.yml`, `scripts/vpn-*`, `ssh-allow-me` multi-firewall assumptions, TFC `vpn` workspace refs, secrets keys (`vpn_*`, shared `hcloud_token`), `.cursor/plans|ideas` vpn manuals, rednaw-map `iac` bullet. Flag every shared-secret path. No code moves yet.

**Human must:** confirm Hetzner UI: current project name(s); whether a second Cloud project already exists under this customer.

### 1. New Hetzner Cloud project (same customer) — parallel, do not touch live box

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — document VPN-only resources for the **new** Cloud project; TF/script token source for the private repo; never point new automation at the live `iac` VPN server.

**Human must:** create Hetzner Cloud project `vpn` (name TBD) under the **existing** customer; create VPN-only Read & Write token there; keep the existing shared/`iac` token working until EU decommission; never store platform + VPN tokens in one file.

### 2. Private VPN git repo + scripts (can start after Human creates repo + Hetzner project)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — scaffold minimal private repo: `hcloud` scripts for provision / wipe / renew-ip; bootstrap for Docker/Xray; emit-link (**one** shared UUID); README. **No Terraform, no TFC, no SOPS, no platform modules.** Only you have push access to workflows/scripts.

**Human must:** create private repo under the **existing** GitHub account/org; invite two friends as **Read** or **Triage** (not Write); put **only** VPN Hetzner token + `vpn_*` in GH Actions secrets; create the sticky issue (number pinned in repo config/README).

### 3. Sticky-issue renew workflow

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — workflow `on: issue_comment` (and optional `workflow_dispatch` for you): only the dedicated issue number; allowlisted comment authors; optional `/renew` body match; `concurrency: 1`; `hcloud` renumber → rebuild `vless://` → **PATCH issue body** with link + UTC timestamp → comment “renewed” on the thread. Permissions: `issues: write`, secrets for Hetzner. Mask token. Docs: friend opens issue → comment `/renew` → wait → copy link from description → re-import OneXray (everyone).

**Human must:** dry-run (you + one friend); confirm platform + live `iac` trip VPN untouched; Mac `task vpn:provision:renew-ip` on **iac** remains trip break-glass until EU.

### 4. Excise VPN from platform `iac` + decommission live trip VPN (**EU only**)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — **after return:** destroy/decommission `iac` TFC `vpn` stack; remove VPN TF/Ansible/tasks/scripts from `iac`; platform `ssh-allow-me` platform-only; update `project.mdc` / README; stub-link to private VPN repo.

**Human must:** back in EU — confirm new VPN path is trusted (or accept no travel VPN); then destroy old VPN; rotate **dead** the old shared Hetzner token; purge `vpn_*` from platform `secrets` if no longer needed; update `rednaw-map`.

### 5. Scrub public `iac` after VPN excision (EU, after Do 4)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — confirm public tree has no VPN paths/docs/tasks; note that **git history** may still contain old VPN recipes (accept, or later history rewrite — out of scope unless asked); Western-only posture in `project.mdc` / README.

**Human must:** smoke platform admin from EU; accept that past public commits already exposed the old VPN *shape* (not the live UUID/keys if those stayed in private secrets).

### 6. Docs during build vs after cutover

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — while in China: document the **new** repo’s operator path in that repo; leave [vpn-travel-china.md](vpn-travel-china.md) pointed at live `iac` VPN. After EU decommission: retarget trip plan/manual to private repo + CI renew.

**Human must:** optional: drill CI renew on the new box before EU (still keep trip clients on `iac` VPN until home unless explicitly cut over later).
