# ROADMAP — Ghost Core Arena

Each milestone is testable in game and ends with `./build.sh --strict` at 0 errors plus a
smoke-test list for the human tester. Design: `DESIGN.md`. Terms: `GLOSSARY.md`.

**Keep this file current**: when a feature lands, tick it and update the milestone status line.

Status legend: ⬜ planned · 🟡 code-complete, needs in-game test · ✅ verified in game.

**Current target: S0** — scaffold.

## S0 — Scaffold

- 🟡 Build/validate/run/release harness copied from Slay the Sector; tools vendored in `tools/`.
- 🟡 Hello world: `[GhostCoreArena] Hello world: application loaded` (launch) and
  `... game loaded (newGame=…)` (new game / load) appear in `starsector.log`.
