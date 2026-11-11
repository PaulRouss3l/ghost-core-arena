# Research: community data on Starsector ship rankings

Ticket: #2 ("Is there existing community data on ship rankings?"). Map: #1.
Researched 2026-11-11 against Starsector 0.98a-RC5 (local install).

## Question

Is there existing community data that ranks Starsector ships (vanilla and popular mods) by
strength or rarity, which could seed the Shop's Rarity override table?

## Short answer

No machine-readable, current (0.98a), licensed ranking exists. What exists is:

- **Opinion tier lists** (forum threads, Reddit images): vanilla lists are years old
  (pre-0.98a) and rank *usefulness/power*, never availability. Mod lists cover a handful
  of mods (Interstellar Imperium, Dassault-Mikoyan, Blackrock, Mayasuran) and are images.
- **Stat databases** (wiki, SST, spreadsheets): current-ish and broad, but they hold raw
  stats, not rankings. Nothing they offer beats reading the CSVs ourselves.
- **AI fleet-building tournaments** on the forum: real AI-vs-AI results, but per *fleet*,
  not per ship, with ban lists, and they ended around 0.9.1a (2020).

The best "availability" signal is **in the game data itself** (`rarity` column, `rare_bp`
tag, blueprint tags, faction role weights). The Rarity derivation should use those, and the
override table should stay hand-curated, with the forum tier lists as a reading aid only.

## Sources

Access note: fractalsoftworks.com, reddit.com and web.archive.org all refused automated
fetches during this research (HTTP 402/403/429). Forum and Reddit details below come from
search-engine snippets of those pages, not a full read. Treat them as leads to open in a
browser, not as verified content.

### 1. In-game data (primary, authoritative)

| Field | Where | What it says |
|---|---|---|
| `rarity` column | `data/hulls/ship_data.csv` (col 51) | Float 0-1, lower = rarer. Vanilla sets it on only 3 of 200 hulls: `vanguard` 0.75, `tempest` 0.75, `hyperion` 0.5. Same semantics as weapon `rarity` (wiki: "number between 0 and 1 with lower being rarer", https://starsector.wiki.gg/wiki/Weapon_data.csv). |
| `rare_bp` tag | `ship_data.csv` `tags` | 38 vanilla hulls, e.g. hyperion, omen, tempest, afflictor, shade, medusa, harbinger, eagle, champion, apogee, aurora, doom, grendel, revenant, onslaught, astral, conquest, paragon, odyssey, legion, invictus, pegasus, retribution. |
| Blueprint tags | same | `base_bp` (20), `midline_bp` (10), `lowtech_bp` (5), `hightech_bp` (3): common, faction-starter blueprints. |
| Non-obtainable tags | same | `restricted`, `no_dealer`, `no_sell`, `remnant`, `derelict`, `omega`, `threat`, `dweller`, `monster`, `auto_rec`. |
| `fleet pts`, `base value` | same | Deployment points and credit cost: the cost axis. |
| Role weights | `data/world/factions/default_ship_roles.json` | Per-variant spawn weights per role (e.g. `combatSmallForSmallFleet`), with dev comments on which ships are "annoying" to fight (Hyperion, Centurion, Vanguard commented out). An availability axis from the developer. |

Mods use the same fields. Installed mods checked locally:

| Mod | Hulls | `rarity` set | `rare_bp` |
|---|---|---|---|
| BigBeans Ship Compilation 0.1.98.85 | 57 | 9 | 29 |
| Hazard Mining Incorporated 0.4.0e | 156 | 23 | 8 |
| HMI Supervillains 0.0.5d | 54 | 10 | 18 |
| Mayasuran Navy 12.0.0 | 66 | 0 | 19 |
| Random Assortment of Things 3.3.1 | 42 | 0 | 1 |
| Secrets of the Frontier 0.15.1 | 51 | 1 | 1 |

- Coverage: vanilla plus every mod, automatically. Current: always matches the installed version.
- Basis: availability (rarity, blueprint tags, role weights) and cost (DP, base value). Not power.
- Reuse: read at runtime from whatever the player has installed. Nothing is redistributed.

### 2. Starsector Wiki, "Ship" page

- URL: https://starsector.wiki.gg/wiki/Ship (also `/wiki/Ships`)
- Coverage: vanilla only. Format: HTML tables per hull size/role (DP, OP, base value, supplies, etc.).
- Current: page says "Up-to-date for latest version, 0.98a".
- Basis: none. Stats only, no tiers or rarity.
- Reuse: CC BY-SA 4.0 (footer). Pre-March-2024 pages adapted from the Fandom wiki.
- Verdict: duplicates `ship_data.csv`. No ranking value.

### 3. Fractal Softworks forum: vanilla tier lists

| Thread | URL | Notes from snippets |
|---|---|---|
| "Ship Tier List" (Dark.Revenant) | https://fractalsoftworks.com/forum/index.php?topic=13342.0 | Ranks by "general usefulness": pick the higher tier for the same role. Letter tiers. Paragon A, Eagle "most well-rounded", Tempest top skirmisher. 200+ replies arguing placements. Era roughly 0.8-0.9 (2018). |
| "Starsector Ship Tiers" (older) | https://fractalsoftworks.com/forum/index.php?topic=8962.0 | Numeric tiers 1-5 by usefulness ("powerful does not mean higher tier"). Also covers fighters. Pre-0.8, very old. |
| "My personal vanilla Starsector ships Tier-list" | https://fractalsoftworks.com/forum/index.php?topic=18707.0 | One player's S-F list. S tier: Tempest, Afflictor, Drover, Aurora (player), Doom, Paragon. ~2020 (0.9.x). |
| "Ship tier list" | https://fractalsoftworks.com/forum/index.php?topic=19630.0 | Another discussion thread. Content not retrieved. |
| "Ship tier list based on how easy it is to get officers for them" | https://fractalsoftworks.com/forum/index.php?topic=32467.0 | Joke/niche basis (officer rolls). Top tier: Hyperion, Champion, Gryphon, Atlas Mk II. Recent topic id (0.97a-0.98a era). |

- Format: forum post text/images. No structured data.
- Basis: power/usefulness, often split by AI vs player piloting. Never availability.
- Reuse: no stated licence. Forum posts are the authors' copyright. Fine to read for inspiration, not to copy wholesale.

### 4. Reddit r/starsector tier lists

- Vanilla: lists by **Grevious69** (per-hull-size, separate AI-piloted and player-piloted grades)
  are cited as the model for later lists. A 2019 post by PureLSD links capital, cruiser and
  destroyer lists. The originals could not be opened. They predate 0.98a.
- Mods: **thecheeseking9** series (2023-2024), image tier lists with an "AI / player" double grade
  (e.g. "Interrex: B / A-"):
  - Interstellar Imperium 2.6.2e: capital, cruiser, destroyer, frigate, fighters; 2.6.4 weapons.
    e.g. https://www.reddit.com/r/starsector/comments/17lljsu/interstellar_imperium_262e_cruiser_ship_tier_list/
  - Dassault-Mikoyan Engineering 1.6a: destroyer, cruiser, capital, fighters, weapons.
    e.g. https://www.reddit.com/r/starsector/comments/12bnaqu/
  - Blackrock Drive Yards 0.9.1a (weapons), Mayasuran Navy.
  - Also cross-posted on the forum: "Interstellar Imperium 2.6.2e Capital ship tier list by Nemoto",
    https://fractalsoftworks.com/forum/index.php?topic=30852.0
- 0.98a: only a ballistic *weapon* tier list turned up
  (https://www.reddit.com/r/starsector/comments/1kky9ta/ballistic_weapon_tier_list_098a/). No 0.98a ship list found.
- Format: images. Basis: author's own experience ("mainly my own feelings"). Reuse: no licence.
- TierMaker template "Starsector 0.97a Ships" (https://tiermaker.com/create/starsector-097a-ships-17522421):
  a blank template, no aggregated ranking.

### 5. Stat databases and spreadsheets

| Source | URL | Coverage | Current | Ranking? |
|---|---|---|---|---|
| Star Sector Toolbox (SST) | https://fractalsoftworks.com/forum/index.php?topic=32948.0 / https://sst.lib00.com | Vanilla. Mod upload/API was "planned" (May 2025). | 0.97a-rc11 and 0.98a-rc8 | No. Stats DB, EN/CN. Terms not stated beyond "free to use". |
| "Ships and Weapons data spreadsheet" (Iannar) | https://fractalsoftworks.com/forum/index.php?topic=22955.0 | Vanilla plus some mods, hullmod modifiers | Last seen update 0.96 | No |
| "Ship/Item database [Vanilla and Mods] (WIP)" | https://fractalsoftworks.com/forum/index.php?topic=11332.0 | Partial, abandoned | ~2016 | No |
| [0.98a] Ship Browser (in-game mod) | https://fractalsoftworks.com/forum/index.php?topic=26261.0 | Whatever is installed | 0.98a | No, browsing only |

None of these hold anything we can't compute from the CSVs.

### 6. AI Fleet Building Tournaments (forum)

- Series of AI-vs-AI fleet tournaments, 2nd through 11th, e.g.
  https://fractalsoftworks.com/forum/index.php?topic=11539.0 (2nd),
  https://fractalsoftworks.com/forum/index.php?topic=18572.0 (10th, June 2020),
  https://fractalsoftworks.com/forum/index.php?topic=19267.0 (11th, ~0.9.1a).
- Coverage: vanilla plus mod factions (e.g. Tiandong, Interstellar Imperium, P.A.C.K.).
- Format: forum posts plus linked Google Sheets score sheets, per team, not per ship.
  Ban lists (some capitals, a hullmod) show which ships were seen as overpowered.
- Current: no tournament found after the 11th (~2020). Pre-0.95.
- Basis: AI-piloted combat power in a fixed DP budget. That is the closest match to our autobattler,
  but the data is fleet-level and stale.
- Related, newer: "AI rebellion tournament", https://fractalsoftworks.com/forum/index.php?topic=23785.0
  (not read).

## Recommendation

1. **Don't seed the override table from community lists.** None is current, structured or
   licensed. All rank power rather than availability. All cover a different set of ships than
   the player will have installed.
2. **Derive Rarity from in-game data first**, in this order: the explicit `rarity` column
   (when set) > `rare_bp` / blueprint-package tags > exclusion tags (`restricted`, `no_dealer`,
   `omega`, `remnant`, `threat`, `dweller`, `monster`) > hull size and DP. Optionally use
   `default_ship_roles.json` weights as a tie-breaker. This covers mods automatically, because
   mod authors use the same fields (see the table in section 1).
3. **Keep the override table small and hand-curated**, for ships that are
   strong for their cost in AI hands. Read Dark.Revenant's forum list (topic 13342) and the Grevious69
   or thecheeseking9 "AI" grades as a checklist, not as data. Recurring vanilla candidates:
   Tempest, Afflictor, Hyperion, Doom, Paragon, Aurora, Medusa, Eagle, Champion. Write the
   overrides ourselves, so there is no licence issue.
4. If power data is ever needed, run our own AI-vs-AI sims (the autobattler's own match
   results are the natural source) rather than relying on 2020 tournament sheets.
