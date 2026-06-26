# Skills ↔ Docs Rebalance — Design

**Date:** 2026-06-26
**Status:** Approved design, pending spec review → implementation plan
**Repos:** `goldsky-agent` (skills) + `goldsky-io/docs` (docs)

## Problem

The Goldsky agent skills and the published docs carry heavily duplicated
reference content (sink fields, SQL functions, CLI flags, dataset schemas,
chain prefixes, secret formats). The docs are already comprehensive and
reasonably agent-friendly, and a hosted docs MCP already exists
(`https://docs.goldsky.com/mcp`). The skills are the redundant layer.

Separately, both `skills/` and the docs are ingested into the Goldsky chatbot
Bedrock knowledge base (KB) as two data sources, so the duplication is also
present in the KB.

## Goal

Make the **docs the single source of truth for reference** (ultra
agent-friendly, surfaced via the docs MCP) and reduce the **skills to recipes**
— procedural workflows that support the docs. Reduce skill surface area, push
reference into docs, and have skills point to docs rather than restate them.

## Governing model

- **Docs = reference source of truth.** Every "what is / what fields / what
  flags / what functions" answer lives in docs, surfaced to agents via the docs
  MCP with a deep-link fallback.
- **Skills = recipes.** Procedural workflows only: decision trees, step
  sequences, doctors, builders, migrations. When a recipe needs reference
  detail it emits the standard pointer:
  > "For full X, search the Goldsky docs MCP for `<term>`, or see `<deep-link>`."
- **One router skill** (`goldsky`, new) is the thin front door: MCP-install
  nudge, intent→recipe routing, and a catch for bare reference questions.

## Key decisions (locked)

1. **Reference channel:** MCP-preferred + deep-link fallback. Works with or
   without the MCP installed; ~1 extra line per pointer.
2. **Reduction depth:** aggressive collapse — ~10 recipe skills + 1 router;
   delete the 6 standalone reference skills.
3. **Scope:** full rebalance across both repos — author gap-filling docs to
   absorb unique skill content.
4. **Docs coordination:** all docs-side changes on a branch/PR the user merges
   after their in-flight docs work settles. Lowest collision risk.
5. **Router:** keep one thin `goldsky` router/index skill (Approach A), so
   ad-hoc reference questions have something to catch them and the MCP-install
   nudge lives in one place.
6. **KB ingestion:** retire skills→KB ingestion as the **final** step, gated on
   docs absorbing the chatbot-relevant procedural knowledge. End state: KB =
   docs only. This adds a "procedural knowledge → docs" deliverable to the docs
   side and retires `sync-kb.yml`'s skills leg (eliminating the `--delete`
   KB-gap risk).

## Guardrails (non-negotiable)

1. **No deletion without a verified, live docs route.** A skill section is
   removed only once its docs home exists and is confirmed via the Mintlify
   docs MCP.
2. **Rescue before delete.** Script dependencies and curated non-doc content
   are relocated, never dropped.
3. **Recipes stay offline-capable on the procedural path.** Only *reference*
   lookups defer to docs/MCP; the steps themselves never require network.

## End-state skill set (~10 recipes + 1 router)

| Skill | Disposition |
|---|---|
| `turbo-builder` | Keep (recipe). Absorbs the architecture-decision matrix from `turbo-pipelines`. |
| `turbo-doctor` | Keep (recipe). **Rescues** `error-patterns.json` + `analyze-logs.sh` from `turbo-operations`. |
| `turbo-transforms` | Keep (recipe), slimmed. Pattern catalogs → docs; keep the "how to approach a transform" workflow. *Open: could merge into `turbo-builder` — minor.* |
| `mirror-doctor` | Keep (recipe). |
| `compose` / `compose-doctor` | Keep (recipes). |
| `subgraph-builder` | Keep (recipe). `references/` slimmed: general reference → docs, curated idioms (`schema-and-mappings` gotchas) stay. |
| `subgraph-doctor` / `subgraph-migrate` | Keep (recipes). |
| `auth-setup` | Keep (recipe). |
| `goldsky` (**new**) | Thin router/index: MCP-install nudge, intent→recipe routing, catch reference questions. |
| ~~`turbo-pipelines`~~ | Delete → docs (`/turbo-pipelines/*`). Decision matrix rescued to `turbo-builder`. |
| ~~`turbo-operations`~~ | Delete → docs (lifecycle/states). Tooling rescued to `turbo-doctor`. |
| ~~`compose-reference`~~ | Delete → docs (`/compose/*`). |
| ~~`mirror`~~ | Delete → docs (`/mirror/*` + `/mirror-vs-turbo`). Decision logic already in docs. |
| ~~`edge`~~ | Delete → docs (`/edge-rpc/*`); setup is mostly dashboard-driven. Router catches "I need an RPC endpoint." |
| ~~`datasets`~~ | Delete → docs. `chain-prefixes` lookup needs a **new consolidated docs page** (gap). |

## Docs-side work (branch/PR the user merges)

**A. Gap-filling reference pages** — author *only* what docs don't already
cover (verify each via the Mintlify MCP first):
- Consolidated **chain-prefix table** (from `chain-prefixes.json`) — likely a
  real gap; `chains/` is per-chain with no single prefix map.
- Turbo **pipeline states / lifecycle** reference (from `turbo-operations`).
- **Architecture-decision matrix / validation checklist** (from
  `turbo-pipelines`) — partly exists; fill gaps.
- **Advanced transform patterns** (`evm-patterns`, `solana-patterns` from
  `turbo-transforms/references`).

**B. Procedural-knowledge pages** (KB-gated requirement) — so the chatbot
retains this once skills leave the KB:
- Troubleshooting guides absorbing **doctor decision logic + `error-patterns.json`
  → fix mappings** (turbo, mirror, subgraph, compose).
- Conceptual "how to build X" guides mirroring the builders' *knowledge* (not
  the agent-execution steps).

**C. Cross-linking:**
- Update the docs `ai-skills` page to the recipe-only set (drop the 6 deleted
  skills, refresh the quick-start table).
- Ensure the skill→doc routes are stable and exist.
- Light skills↔MCP cross-links.

## Skills-side work (goldsky-agent), gated waves

- **Wave 0 — additive, lands anytime:** create the `goldsky` router skill; add
  the MCP+link pointer pattern + MCP-install nudge to recipe headers.
- **Wave 1 — rescue:** `error-patterns.json` + `analyze-logs.sh` →
  `turbo-doctor`; architecture matrix → `turbo-builder`; curated idioms
  preserved; chain-prefix lookup repointed to its new docs page.
- **Wave 2 — collapse:** delete the 6 reference skills + slim
  `turbo-transforms`/`subgraph-builder` references. Each deletion **gated on its
  docs route being live** (verified).
- **Wave 3 — KB retirement (final):** once docs cover the procedural knowledge
  and the chatbot is verified not to regress → remove the skills data-source leg
  from `sync-kb.yml`. KB = docs only.

## Cross-repo ordering

Docs branch authored → **user merges it** → skills Waves 1–2 land against
now-live routes (Wave 0 can go before that; routes already live today need no
wait) → Wave 3 last.

## Success criteria

1. No skill reference deleted without a verified live docs route.
2. Rescue-before-delete honored (scripts, curated idioms, chain-prefixes,
   Mirror-vs-Turbo decision logic).
3. Recipes' procedural path works offline.
4. Every pointer resolves (MCP term *and* deep link).
5. Chatbot doesn't regress — procedural knowledge is in docs before the KB
   skills-source is retired.
6. End state: single KB source (docs), skills are install-only, duplication
   gone.

## Open (minor, resolve during planning)

- Whether `turbo-transforms` stays a separate recipe or merges into
  `turbo-builder`.
- Exact destination for each `subgraph-builder/references/*` file
  (recipe-resident curated idiom vs. general reference → docs), decided
  per-file.
