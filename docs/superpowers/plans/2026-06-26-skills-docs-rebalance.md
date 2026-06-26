# Skills ↔ Docs Rebalance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the docs the single source of truth for reference (surfaced via the docs MCP) and reduce the Goldsky agent skills to ~10 procedural recipes + 1 router, eliminating duplicated surface area and ultimately retiring skills→KB ingestion.

**Architecture:** Two repos. Docs repo (`goldsky-io/docs`) gets gap-filling reference pages + procedural-knowledge pages + an updated `ai-skills` page, all on one branch the user merges. Skills repo (`goldsky-agent`) collapses in gated waves: additive router/pointers first, then rescue of curated/script content into recipes, then deletion of 6 reference skills (each gated on a verified-live docs route), then retirement of the skills KB data source.

**Tech Stack:** Markdown/MDX (Mintlify, nav config `docs.json`), Claude/Cursor skill `SKILL.md` files, a GitHub Actions workflow (`sync-kb.yml`), the Mintlify docs MCP for coverage verification.

**Verification model:** This is a content/refactor plan, not code-with-unit-tests. The TDD loop maps to **verify-gap → author/relocate → verify-coverage**: confirm a docs route is missing (or content is present), make the change, then confirm via the Mintlify docs MCP (`search_goldsky` / `query_docs_filesystem_goldsky`) and `grep` sweeps that coverage exists and no reference dangles.

**Source spec:** `docs/superpowers/specs/2026-06-26-skills-docs-rebalance-design.md`

---

## Guardrails (apply to every task)

1. **No deletion without a verified, live docs route.** Before deleting any skill reference content, confirm its docs home exists via the Mintlify MCP.
2. **Rescue before delete.** Relocate script deps + curated non-doc content; never drop.
3. **Recipes stay offline-capable on the procedural path.** Only reference lookups defer to docs/MCP.

---

## Standard pointer snippet (used throughout)

When a recipe needs reference detail, insert this pattern (adapt term/route):

```markdown
> For full <thing>, search the Goldsky docs MCP for `<search term>`, or see
> https://docs.goldsky.com/<route>. Not seeing the MCP? Install it:
> https://docs.goldsky.com/mcp-server
```

---

# Phase A — Docs repo (branch `app-4964-docs-rebalance`, user merges)

Repo: `/Users/sophia/Code/docs`. Nav config: `docs.json` (every new page must be added to navigation).

### Task A0: Branch + coverage matrix

**Files:**
- Create: `/Users/sophia/Code/docs` branch `app-4964-docs-rebalance`

- [ ] **Step 1: Create the docs branch**

```bash
cd /Users/sophia/Code/docs && git checkout main && git pull && git checkout -b app-4964-docs-rebalance
```

- [ ] **Step 2: Build the coverage matrix**

For each deletion target's content, query the docs MCP to record EXISTS vs GAP. Run these via the Mintlify MCP (`query_docs_filesystem_goldsky`):

```
ls /turbo-pipelines /mirror /compose /edge-rpc /reference
rg -il "chain prefix|matic|dataset_name" / -g '*.mdx'
rg -il "pipeline state|ERROR state|lifecycle|job mode" /turbo-pipelines -g '*.mdx'
rg -il "evm_log_decode|solana decode|decode-once" /turbo-pipelines/transforms -g '*.mdx'
```

- [ ] **Step 3: Record the matrix in the plan's tracking ticket (APP-4964)**

Write a short table: content → docs route (EXISTS) or → "GAP, author in Task A_n". This drives which A-tasks actually run (skip tasks whose content already exists).

Expected: each of {chain-prefix table, pipeline states/lifecycle, architecture-decision matrix, validation checklist, advanced transform patterns, troubleshooting/error-patterns, build-knowledge guides} is marked EXISTS or GAP.

---

### Task A1: Consolidated chain-prefix reference page (likely GAP)

**Files:**
- Create: `/Users/sophia/Code/docs/turbo-pipelines/reference/chain-prefixes.mdx`
- Modify: `/Users/sophia/Code/docs/docs.json` (add to navigation)
- Source: `goldsky-agent/skills/datasets/data/chain-prefixes.json`

- [ ] **Step 1: Confirm the gap**

MCP: `rg -l "chain prefix" / -g '*.mdx'` → expected: no single consolidated prefix-map page.

- [ ] **Step 2: Author the page**

Port `chain-prefixes.json` into a Mintlify table page. Frontmatter + structure:

```mdx
---
title: Chain prefixes
description: Dataset name prefixes and chain IDs for every supported chain.
---

Dataset names follow `<chain_prefix>.<dataset_type>` (e.g. `base.erc20_transfers`).
Use the prefix below — note non-obvious ones like Polygon = `matic`.

| Chain | Prefix | Chain ID | Example | Notes |
| ----- | ------ | -------- | ------- | ----- |
| Ethereum | `ethereum` | 1 | `ethereum.erc20_transfers` | |
| Polygon | `matic` | 137 | `matic.erc20_transfers` | **NOT** `polygon` |
| ... port every row from chain-prefixes.json ... |
```

- [ ] **Step 3: Add to navigation**

Add `turbo-pipelines/reference/chain-prefixes` to the appropriate group in `docs.json`.

- [ ] **Step 4: Verify locally**

```bash
cd /Users/sophia/Code/docs && rg -c "matic" turbo-pipelines/reference/chain-prefixes.mdx
```
Expected: page exists, contains all prefixes, is referenced in `docs.json`.

- [ ] **Step 5: Commit**

```bash
git add turbo-pipelines/reference/chain-prefixes.mdx docs.json
git commit -m "docs: add consolidated chain-prefixes reference (APP-4964)"
```

---

### Task A2: Pipeline states & lifecycle reference (verify, then fill gap)

**Files:**
- Create or Modify: `/Users/sophia/Code/docs/turbo-pipelines/reference/lifecycle.mdx` (create only if Task A0 marked GAP)
- Modify: `/Users/sophia/Code/docs/docs.json`
- Source: `goldsky-agent/skills/turbo-operations/SKILL.md` (state tables, streaming vs job-mode lifecycle)

- [ ] **Step 1: Skip-or-author decision** — if A0 marked this EXISTS, skip Task A2 and note the existing route. Otherwise continue.

- [ ] **Step 2: Author the page** porting the pipeline-states table (6 states) and the streaming-vs-job-mode lifecycle (8 rows) from `turbo-operations/SKILL.md`. Use a `| State | Meaning | Next actions |` table.

- [ ] **Step 3: Add to `docs.json` navigation.**

- [ ] **Step 4: Verify** via MCP `rg -i "ERROR|RUNNING|job mode" /turbo-pipelines/reference/lifecycle.mdx` returns the states.

- [ ] **Step 5: Commit** `git commit -m "docs: turbo pipeline states & lifecycle reference (APP-4964)"`

---

### Task A3: Architecture-decision matrix & validation checklist (verify, then fill gap)

**Files:**
- Modify/Create: `/Users/sophia/Code/docs/turbo-pipelines/reference/architecture.mdx` and/or `.../validation-checklist.mdx`
- Modify: `docs.json`
- Source: `goldsky-agent/skills/turbo-pipelines/SKILL.md` + `skills/turbo-pipelines/references/architecture-patterns.md`, `validation-checklist.md`

- [ ] **Step 1: Skip-or-author** per A0 matrix; only author the portions marked GAP (architecture-patterns and validation-checklist were skill-only).

- [ ] **Step 2: Author** the source-type decision matrix + the deployment validation checklist as docs pages/sections.

- [ ] **Step 3: Add to `docs.json`.**

- [ ] **Step 4: Verify** the pages render and contain the matrix/checklist.

- [ ] **Step 5: Commit** `git commit -m "docs: turbo architecture decision matrix + validation checklist (APP-4964)"`

---

### Task A4: Advanced transform patterns (verify, then fill gap)

**Files:**
- Modify: `/Users/sophia/Code/docs/turbo-pipelines/transforms/sql.mdx` (extend) and/or create `transforms/patterns.mdx`
- Modify: `docs.json`
- Source: `goldsky-agent/skills/turbo-transforms/references/evm-patterns.md`, `solana-patterns.md`

- [ ] **Step 1: Skip-or-author** per A0 (basics already in `transforms/sql.mdx`; advanced patterns like decode-once-filter-many, UNION ALL normalization, Solana instruction patterns may be GAP).

- [ ] **Step 2: Author** the GAP patterns into `transforms/patterns.mdx` (or extend `sql.mdx`), preserving the code examples from the source files.

- [ ] **Step 3: Add to `docs.json` if new page.**

- [ ] **Step 4: Verify** MCP `rg -i "decode-once|UNION ALL|instruction" /turbo-pipelines/transforms` returns matches.

- [ ] **Step 5: Commit** `git commit -m "docs: advanced turbo transform patterns (APP-4964)"`

---

### Task A5: Troubleshooting / procedural-knowledge guides (KB-gated requirement)

**Files:**
- Create: `/Users/sophia/Code/docs/turbo-pipelines/troubleshooting.mdx` (and mirror/subgraph/compose equivalents if GAP)
- Modify: `docs.json`
- Source: `goldsky-agent/skills/turbo-operations/data/error-patterns.json`, the `*-doctor` SKILL.md decision logic

- [ ] **Step 1: Extract the knowledge** — from `error-patterns.json`, each entry is `{pattern, cause, solution}`. From each doctor SKILL.md, extract the symptom→diagnosis→fix decision logic (NOT the agent-execution scaffolding like AskUserQuestion calls).

- [ ] **Step 2: Author troubleshooting pages** as `| Symptom / error | Likely cause | Fix |` tables plus short prose, one per product where GAP (turbo, mirror, subgraph, compose).

- [ ] **Step 3: Add to `docs.json`.**

- [ ] **Step 4: Verify** MCP search for 3 sample error strings from `error-patterns.json` each return a docs hit.

Expected: every error pattern and doctor decision branch that the chatbot should answer now has a docs home. This is the gate for Phase E (KB retirement).

- [ ] **Step 5: Commit** `git commit -m "docs: troubleshooting guides absorbing doctor logic + error patterns (APP-4964)"`

---

### Task A6: Update the `ai-skills` page + cross-links

**Files:**
- Modify: `/Users/sophia/Code/docs/ai-skills.mdx`
- Modify: `/Users/sophia/Code/docs/mcp-server.mdx` (light cross-link only)

- [ ] **Step 1: Update the quick-start table** in `ai-skills.mdx` to the recipe-only set. Remove rows for deleted skills: `turbo-pipelines`, `compose-reference`, `mirror`, `edge`, `datasets`, `turbo-operations`. Keep builders, doctors, migrate, compose, auth-setup; add the `goldsky` router.

- [ ] **Step 2: Update prose** describing "reference skills" — change to "skills are recipes; reference lives in the docs, searchable via the docs MCP."

- [ ] **Step 3: Verify** MCP/`rg` that `ai-skills.mdx` no longer names the 6 deleted skills.

```bash
cd /Users/sophia/Code/docs && rg -n "turbo-pipelines|compose-reference|/mirror\b|/edge\b|/datasets|turbo-operations" ai-skills.mdx
```
Expected: only references that are doc routes (e.g. `/mirror/...`), not skill names.

- [ ] **Step 4: Commit** `git commit -m "docs: ai-skills page reflects recipe-only skill set (APP-4964)"`

---

### Task A7: Open the docs PR

- [ ] **Step 1: Push + open PR**

```bash
cd /Users/sophia/Code/docs && git push -u origin app-4964-docs-rebalance
gh pr create --base main --title "docs: absorb skill reference + procedural knowledge (APP-4964)" \
  --body "Gap-filling reference pages + troubleshooting guides + ai-skills update for the skills↔docs rebalance. Merges when in-flight docs work settles. Tracks APP-4964."
```

- [ ] **Step 2: Record the PR URL in APP-4964.** This PR merging is the gate for Phase D deletions and Phase E.

---

# Phase B — Skills repo Wave 0 (additive, can land immediately)

Repo: `/Users/sophia/Code/goldsky-agent`. Branch `sophia/app-4964-skills-wave0`.

### Task B1: Create the `goldsky` router skill

**Files:**
- Create: `goldsky-agent/skills/goldsky/SKILL.md`

- [ ] **Step 1: Branch**

```bash
cd /Users/sophia/Code/goldsky-agent && git checkout main && git pull && git checkout -b sophia/app-4964-skills-wave0
```

- [ ] **Step 2: Write the router SKILL.md**

```markdown
---
name: goldsky
description: "Entry point for Goldsky. Use when the user mentions Goldsky but the task doesn't clearly map to a specific workflow, when they ask a reference question (dataset names, sink fields, CLI flags, SQL functions, chain prefixes), or when a doc/reference lookup is failing. Routes to the right recipe skill and to the Goldsky docs."
---

# Goldsky

## Reference questions → the docs
For anything factual (dataset names, sink/secret fields, CLI flags, SQL
functions, chain prefixes, pipeline states), search the **Goldsky docs MCP**,
or browse https://docs.goldsky.com. The docs are the source of truth.

**No docs MCP available?** Install it (one-time):
https://docs.goldsky.com/mcp-server

## Task → recipe routing
| The user wants to… | Use skill |
| --- | --- |
| Build a Turbo pipeline | `turbo-builder` |
| Fix a broken Turbo pipeline | `turbo-doctor` |
| Write a SQL/TS/dynamic transform | `turbo-transforms` |
| Fix a broken Mirror pipeline | `mirror-doctor` |
| Build a Compose app | `compose` |
| Fix a broken Compose app | `compose-doctor` |
| Build/deploy a subgraph | `subgraph-builder` |
| Fix a broken subgraph | `subgraph-doctor` |
| Migrate a subgraph from The Graph | `subgraph-migrate` |
| Set up the CLI / log in | `auth-setup` |
| Get a managed RPC endpoint | see https://docs.goldsky.com/edge-rpc |
```

- [ ] **Step 3: Verify frontmatter parses** (name/description present, valid YAML).

- [ ] **Step 4: Commit** `git commit -m "feat(skills): add goldsky router/index skill (APP-4964)"`

---

### Task B2: Add the MCP+link pointer pattern to recipe headers

**Files:**
- Modify: `SKILL.md` of each kept recipe: `turbo-builder`, `turbo-doctor`, `turbo-transforms`, `mirror-doctor`, `compose`, `compose-doctor`, `subgraph-builder`, `subgraph-doctor`, `subgraph-migrate`, `auth-setup`

- [ ] **Step 1: Add a short "Reference & docs MCP" note** near the top of each recipe SKILL.md:

```markdown
> **Reference lookups:** for exact fields/flags/functions, search the Goldsky
> docs MCP or see https://docs.goldsky.com. No MCP? https://docs.goldsky.com/mcp-server
```

- [ ] **Step 2: Verify** each of the 10 recipe SKILL.md files contains the note:

```bash
cd /Users/sophia/Code/goldsky-agent && for s in turbo-builder turbo-doctor turbo-transforms mirror-doctor compose compose-doctor subgraph-builder subgraph-doctor subgraph-migrate auth-setup; do rg -L -c "mcp-server" skills/$s/SKILL.md >/dev/null && echo "$s OK" || echo "$s MISSING"; done
```
Expected: all 10 print `OK`.

- [ ] **Step 3: Commit** `git commit -m "docs(skills): standard docs-MCP pointer in recipe headers (APP-4964)"`

- [ ] **Step 4: Push + PR (Wave 0 is safe to merge anytime)**

```bash
git push -u origin sophia/app-4964-skills-wave0
gh pr create --base main --title "feat(skills): router skill + docs-MCP pointers (additive, APP-4964)" --body "Wave 0 of the skills↔docs rebalance. Additive only — no deletions. Tracks APP-4964."
```

---

# Phase C — Skills repo Wave 1 (rescue curated/script content)

Branch `sophia/app-4964-skills-rescue` (off main after Wave 0 merges, or stacked).

### Task C1: Move turbo error tooling into `turbo-doctor`

**Files:**
- Move: `skills/turbo-operations/data/error-patterns.json` → `skills/turbo-doctor/data/error-patterns.json`
- Move: `skills/turbo-operations/scripts/analyze-logs.sh` → `skills/turbo-doctor/scripts/analyze-logs.sh`
- Modify: `skills/turbo-doctor/scripts/analyze-logs.sh` (fix the relative path to the JSON)
- Modify: `skills/turbo-doctor/SKILL.md` (reference the relocated tool)

- [ ] **Step 1: Move the files with git**

```bash
cd /Users/sophia/Code/goldsky-agent
mkdir -p skills/turbo-doctor/data skills/turbo-doctor/scripts
git mv skills/turbo-operations/data/error-patterns.json skills/turbo-doctor/data/error-patterns.json
git mv skills/turbo-operations/scripts/analyze-logs.sh skills/turbo-doctor/scripts/analyze-logs.sh
```

- [ ] **Step 2: Fix the path in the script**

In `skills/turbo-doctor/scripts/analyze-logs.sh`, the line
`ERROR_PATTERNS_FILE="$SCRIPT_DIR/../data/error-patterns.json"` still resolves
(both moved together, same relative layout). Confirm by reading the script;
adjust only if the relative path differs.

- [ ] **Step 3: Verify the script still finds its data**

```bash
cd /Users/sophia/Code/goldsky-agent/skills/turbo-doctor && bash scripts/analyze-logs.sh --help 2>&1 | head -5 || true
test -f skills/turbo-doctor/data/error-patterns.json && echo "data present"
```
Expected: script runs without "file not found" for the JSON.

- [ ] **Step 4: Update `turbo-doctor/SKILL.md`** to point at `scripts/analyze-logs.sh` / `data/error-patterns.json` (was previously cross-referencing turbo-operations).

- [ ] **Step 5: Commit** `git commit -m "refactor(skills): move turbo log-analysis tooling into turbo-doctor (APP-4964)"`

---

### Task C2: Rescue the architecture-decision matrix into `turbo-builder`

**Files:**
- Modify: `skills/turbo-builder/SKILL.md`
- Source: `skills/turbo-pipelines/SKILL.md` (architecture decision matrix), `skills/turbo-pipelines/references/architecture-patterns.md`

- [ ] **Step 1: Identify the procedural decision content** (source-type selection matrix, when-to-use patterns) vs pure reference (field tables → docs).

- [ ] **Step 2: Inline the decision matrix** into `turbo-builder/SKILL.md` (it's procedural — drives the build wizard). Leave pure field reference for docs.

- [ ] **Step 3: Verify** `turbo-builder/SKILL.md` now contains the decision matrix.

- [ ] **Step 4: Commit** `git commit -m "refactor(skills): rescue architecture decision matrix into turbo-builder (APP-4964)"`

---

### Task C3: Resolve `subgraph-builder/references/*` and `turbo-transforms/references/*` per-file

**Files:**
- Keep: `skills/subgraph-builder/references/schema-and-mappings.md` (curated idioms — confirmed keep)
- Decide per-file: `performance.md`, `operations.md`, `testing.md`, and `turbo-transforms/references/{evm-patterns,solana-patterns,typescript-transforms,dynamic-tables}.md`

- [ ] **Step 1: Classify each file** — curated procedural idiom (keep in recipe) vs general reference (its content goes to docs in Phase A, file deleted here once the docs route is live).

- [ ] **Step 2: For files whose content moved to docs (Task A4 etc.),** replace the file's body with a one-line pointer OR delete it and update the recipe SKILL.md pointer to the docs route. GATE: only delete once the docs route is verified live (Phase D check).

- [ ] **Step 3: Leave `schema-and-mappings.md` intact**; ensure `subgraph-builder/SKILL.md` still references it.

- [ ] **Step 4: Verify** no recipe SKILL.md points to a deleted local reference file (grep).

- [ ] **Step 5: Commit** `git commit -m "refactor(skills): resolve recipe reference files (keep curated, defer general to docs) (APP-4964)"`

---

# Phase D — Skills repo Wave 2 (collapse, GATED on docs PR merged)

Branch `sophia/app-4964-skills-collapse`. **Do not start until the Phase A docs PR is merged and live.**

### Task D1: Verify every deletion target has a live docs route

**Files:** none (verification only)

- [ ] **Step 1: For each of the 6 skills, confirm docs coverage via the Mintlify MCP** (production docs, post-merge):

```
search_goldsky "postgres sink configuration fields"      # turbo-pipelines
search_goldsky "pipeline states lifecycle"               # turbo-operations
search_goldsky "compose.yaml manifest fields"            # compose-reference
search_goldsky "mirror vs turbo when to use"             # mirror
search_goldsky "edge rpc endpoint setup"                 # edge
search_goldsky "chain prefixes dataset names"            # datasets
```
Expected: each returns a live docs page. Any miss → STOP, that content stays in its skill until docs cover it (loop back to Phase A).

- [ ] **Step 2: Record the verified route for each** (used as the pointer target).

---

### Task D2: Delete the 6 reference skills

**Files:**
- Delete: `skills/turbo-pipelines/`, `skills/turbo-operations/`, `skills/compose-reference/`, `skills/mirror/`, `skills/edge/`, `skills/datasets/`

- [ ] **Step 1: Branch + delete**

```bash
cd /Users/sophia/Code/goldsky-agent && git checkout main && git pull && git checkout -b sophia/app-4964-skills-collapse
git rm -r skills/turbo-pipelines skills/turbo-operations skills/compose-reference skills/mirror skills/edge skills/datasets
```

- [ ] **Step 2: Confirm rescued content already moved** (Wave 1): `error-patterns.json`, `analyze-logs.sh`, architecture matrix, chain-prefixes content. If any rescue is incomplete, STOP and finish Wave 1 first.

- [ ] **Step 3: Commit** `git commit -m "feat(skills): delete 6 reference skills, reference now lives in docs (APP-4964)"`

---

### Task D3: Sweep and fix all cross-references

**Files:**
- Modify: any `SKILL.md`, `README.md`, `SKILLS.md`, plugin manifests referencing the deleted skills

- [ ] **Step 1: Find dangling references**

```bash
cd /Users/sophia/Code/goldsky-agent
grep -rn "turbo-pipelines\|turbo-operations\|compose-reference\|/mirror\b\|/edge\b\|/datasets" skills/ README.md SKILLS.md .claude-plugin/ .cursor-plugin/ 2>/dev/null | grep -v "docs.goldsky.com"
```
Expected after fixes: empty (every remaining mention is a docs route, not a skill reference).

- [ ] **Step 2: Replace each dangling reference** with either a docs route pointer or the relevant recipe (e.g. `/mirror` skill mentions → `mirror-doctor` or `https://docs.goldsky.com/mirror`).

- [ ] **Step 3: Update `README.md` + `SKILLS.md`** skill listings to the recipe-only set + `goldsky` router.

- [ ] **Step 4: Re-run the grep from Step 1** — expected empty.

- [ ] **Step 5: Commit** `git commit -m "chore(skills): clean up references to deleted reference skills (APP-4964)"`

---

### Task D4: Verify pointers + triggers, open PR

- [ ] **Step 1: Verify every docs route referenced in skills resolves**

```bash
cd /Users/sophia/Code/goldsky-agent
rg -o "https://docs.goldsky.com/[A-Za-z0-9/_#-]+" skills/ | sort -u
```
Then spot-check each unique route via the Mintlify MCP (`query_docs_filesystem_goldsky`, `head <route>.mdx`). Expected: all resolve.

- [ ] **Step 2: Sanity-check skill count** = 10 recipes + `goldsky` router = 11 dirs under `skills/`.

```bash
ls -d skills/*/ | wc -l   # expected 11
```

- [ ] **Step 3: Push + PR**

```bash
git push -u origin sophia/app-4964-skills-collapse
gh pr create --base main --title "feat(skills): collapse reference skills into docs-backed recipes (APP-4964)" --body "Wave 2: deletes the 6 reference skills (docs coverage verified live), cleans cross-refs. Tracks APP-4964."
```

---

# Phase E — KB retirement (FINAL, gated on docs PR merged + procedural coverage verified)

Branch `sophia/app-4964-retire-skills-kb`.

### Task E1: Verify the chatbot won't regress

- [ ] **Step 1: Confirm procedural knowledge is in docs** — for 5 representative doctor branches / error patterns (from Task A5), confirm each is answerable from the docs data source (Mintlify MCP search returns a docs page, not a skill).

Expected: all 5 covered. Any miss → STOP, return to Task A5.

---

### Task E2: Remove the skills data-source leg from `sync-kb.yml`

**Files:**
- Modify or Delete: `goldsky-agent/.github/workflows/sync-kb.yml`

- [ ] **Step 1: Decide modify vs retire** — if the workflow only syncs `skills/`, retire the whole workflow; if it also does docs, remove only the skills sync + ingestion steps. (Per current `sync-kb.yml`, it syncs `skills/` only → retire the workflow.)

- [ ] **Step 2: Make the change**

```bash
cd /Users/sophia/Code/goldsky-agent && git checkout main && git pull && git checkout -b sophia/app-4964-retire-skills-kb
git rm .github/workflows/sync-kb.yml
```

- [ ] **Step 3: Note the data-source cleanup** — the Bedrock skills data source + S3 bucket are infra, not in this repo. Add a checklist item to APP-4964 to deprovision/empty them (owner: infra), so a stale skills data source doesn't keep serving deleted content.

- [ ] **Step 4: Commit + PR**

```bash
git commit -m "chore(ci): retire skills→KB ingestion; docs are the sole KB source (APP-4964)"
git push -u origin sophia/app-4964-retire-skills-kb
gh pr create --base main --title "chore: retire skills→KB ingestion (APP-4964)" --body "Final wave. Docs are now the sole KB source; procedural knowledge verified present in docs. Removes sync-kb.yml. Tracks APP-4964."
```

---

### Task E3: Confirm KB still serves after cutover

- [ ] **Step 1: After infra deprovisions the skills data source,** run 3 chatbot queries (reference + troubleshooting + build-how-to) and confirm answers come from docs and are correct. Record in APP-4964. Close the ticket.

---

## Self-review notes

- **Spec coverage:** every spec decision maps to a task — pointers (B1/B2), aggressive collapse (D2), full rebalance/docs authoring (A1–A6), docs coordination via branch/PR (A7), router (B1), KB retirement gated (E1–E3), all three guardrails (A0/D1 gate, C1–C3 rescue, offline note in B2).
- **No placeholders:** skip-or-author tasks (A2–A4) are explicitly conditional on the A0 matrix, not vague TODOs.
- **Consistency:** skill names and the 11-dir end state are consistent across B/D tasks; `error-patterns.json` + `analyze-logs.sh` relative path preserved by moving both together (C1).
