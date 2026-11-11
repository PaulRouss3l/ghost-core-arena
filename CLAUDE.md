# CLAUDE.md — Ghost Core Arena

Context router for AI sessions. Keep this file lean; detail lives in `docs/`.

## What this is

A **Starsector 0.98a** mod. **Java only** (no Kotlin). Concept: TBD (see `docs/DESIGN.md`).
Domain terms: `GLOSSARY.md`.

## Build / run

- Build: `./build.sh` → compiles `src/` into `jars/GhostCoreArena.jar`, then runs the static
  validator. Must report **0 errors** after every change. `./build.sh --strict` before a release.
- Run (debug, attach on `:5005`): `./run.sh`. In VSCode: F5 "Debug Starsector".
- After an in-game test: `python3 tools/log_scan.py --mod .` triages `starsector.log`.
  Mod lines start with `[GhostCoreArena]`.
- Release: bump the version (`mod_info.json`, `ghost_core_arena.version` incl. `directDownloadURL`,
  `CHANGELOG.md`), merge to `main`, then `./release.sh X.Y.Z [--prerelease]` (`--dry-run` first).
  Steps: `docs/DEVELOPMENT.md`.
- Game install: `/home/ubik/Downloads/starsector` (override with `STARSECTOR_DIR`). The repo is
  symlinked into `<install>/mods/ghost-core-arena` (see `docs/DEVELOPMENT.md`).
- Entry class: `com.ghostcorearena.GhostCoreArenaModPlugin` (per `mod_info.json`).

## Tooling

- `tools/` is **vendored** from the `starsector-modding` skill (see `tools/UPSTREAM.md`). Do not
  edit those scripts; configure via `tools/validate_config.json`.
- The full skill is installed at `~/.claude/skills/starsector-modding`. Use its
  `scripts/api_lookup.py` (`class|method|const|uses|grep|rulecmd|javap`) to check any API call
  before using it, and its `references/pitfalls.md` as the review checklist.

## Hard constraints

- **Java only.** Do not introduce Kotlin.
- **Id prefix `gca_`** on every new id (hulls, weapons, factions, entities, rules, memory keys,
  settings keys). The validator enforces it.
- **Never wipe / regenerate the vanilla sector.** The mod is purely additive.
- **Never relocate the player fleet from inside an open dialog** (camera gets stuck).
- **XStream-safe serialization**: saved state holds ids and plain `Serializable` POJOs, not
  references to live world objects. No static fields holding game objects. Alias saved classes in
  `configureXStream`; never rename them after release.

## Workflow

- **When a feature is done, update `docs/ROADMAP.md`** in the same change: tick the item
  (⬜ → 🟡 code-complete, ✅ verified in game) and the "Current target" line.
- New domain terms go in `GLOSSARY.md`; hard-to-reverse design choices get an ADR in `docs/adr/`.
- **Logging** (`GCALog`, ships to players' `starsector.log`): log events, never loops. Info lines for
  rare milestones only; `warn` for real anomalies. Nothing in `advance()`, rendering or per-tick
  code. Verbose tracing, if ever needed, goes behind a `gca_debugLog` setting that defaults to off.

## Pointers

- `GLOSSARY.md` — canonical domain terms.
- `docs/DESIGN.md` — settled design.
- `docs/adr/` — architecture decisions.
- `docs/ROADMAP.md` — milestones and status.
- `docs/API_NOTES.md` — verified Starsector API facts + pitfalls relevant to this mod.

## Reference mods

- Sister project **Slay the Sector** at `/home/ubik/localhost/perso/starsector/slay-the-sector`
  (same harness; mature examples of intel, dialogs, custom UI, battle plugins, console commands).
- API docs mirror: `https://jaghaimo.github.io/starsector-api/`.
- Nexerelin (`Histidine91/Nexerelin`), SecondInCommand / RAT (`Lukas22041`) — examples.
