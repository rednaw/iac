**Speculation / parked.** Not an active three-list plan. Lives in `iac/.cursor/ideas/`.

# Umami follow-ups

Leftovers from the archived platform Umami plan (`../completed/umami.md`). Umami is live on `analytics.rednaw.nl`, dual-running with Simple Analytics (SA) on baglio, unicorn, marialoni, simonacella and tientje-ketama.

## Decided

| | |
|--|--|
| Scope | Parked. Sibling-repo edits need a go per repo. |

## Decide

### How long to keep Umami visit data?

Today there's no retention policy, so data is kept forever. There's no backup either; the history is disposable. OpenObserve keeps 7 days.

| | Option | Trade-off |
|--|--|--|
| **A** | **Keep forever** (status quo) | Simplest; privacy copy can't claim a short window |
| **B** | **90 days** — scheduled delete (Umami UI, else Prefect SQL) | "Stats, not archive"; state N in privacy text |
| **C** | **30 days** — same mechanism as B | Stronger minimization; no year-over-year trends |
| **D** | **7 days** (match OpenObserve) | One story for box data; too short for visitor trends |

Also: whether privacy pages state the period (recommended unless A).

Choice: _unpicked_

## Do

### 0. Idea / map doc sync

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after sibling go: name Umami (self-hosted, dual-run) in `rednaw/.cursor/ideas/portfolio/{private-data,sovereign-exit,portfolio-levers}.md` and the `rednaw-map` platform list.

**Human must:** review those edits.

### 1. compleanno snippet

- [ ] Agent: implemented
- [ ] Human: reviewed

**can start now** (after Human supplies website id)

**Agent will implement** — add the Umami snippet alongside SA in `compleanno/src/app.html`, with `data-exclude-search="true"`. SA uses `data-collect-dnt="true"`; don't add DNT to Umami. Don't remove SA.

**Human must:** create the website in Umami (Domain `rednaw.github.io`), give the `data-website-id`, deploy, then confirm hits in both SA and Umami.

### 2. Privacy copy on dual-run sites

- [ ] Agent: implemented
- [ ] Human: reviewed

**can start now** (per site after go)

**Agent will implement** — privacy text naming SA and Umami (geo from IP via GeoLite2, IP not stored), matching baglio: unicorn, simonacella, marialoni (compleanno once wired). tientje-ketama has no privacy page; add one only if asked.

**Human must:** pick the site, approve the wording, merge and deploy.
