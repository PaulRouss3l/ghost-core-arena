# Research: how Slay the Sector creates, finds and runs its Descent Relay

Ticket: #5. Map: #1. Facts only; the sharing protocol is decided in a later grilling ticket.

**Source.** Slay the Sector (STS) local clone, branch `dev/next` at `186d1b15`, mod version 0.5.4.
All `file:line` refs are relative to `/home/ubik/localhost/perso/starsector/slay-the-sector/`
and abbreviate `src/com/slaythesector/` as `src/`. Starsector API facts come from the game's own
API source (`starfarer.api.zip`, 0.98a-RC8) via `api_lookup.py`.

## 1. Identity: ids, type, tags, memory keys

| What | Value | Where |
|---|---|---|
| Entity id (unique in the sector) | `sts_hub` | `src/util/STSConstants.java:34` |
| Entity tag (used for dialog routing) | `sts_hub` (same string as the id) | `src/util/STSConstants.java:30`, added at `src/world/HubPlacer.java:43` |
| Custom entity type | `sts_hub_station` | `src/util/STSConstants.java:35`, `data/config/custom_entities.json:2-9` |
| Type spec | `baseId: station_mining00`, name "Descent Relay", `nameInText` "descent relay", `shortName` "relay", `showNameOnMap: true`, no tags | `data/config/custom_entities.json:2-9` |
| Faction | `Factions.NEUTRAL` | `src/world/HubPlacer.java:42` |
| Market | none | `src/world/HubPlacer.java:18-19` (class doc) |
| Entity memory on the station | none set | (no `getMemory*` call on the hub anywhere in `src/`) |
| Unused leftover type | `sts_spike_station` ("Descent Relay (spike)") | `data/config/custom_entities.json:36-40`; no reference in `src/` |
| Intel icon | sprite `intel/sts_hub` -> `graphics/icons/intel/sts_descent.png` | `data/config/settings.json:68-70`, `src/intel/HubIntel.java:115` |

Sector memory keys STS owns (all `$sts_` prefixed, `src/util/STSConstants.java:11-31`):

- `$sts_run_state` (sector memory): the active `RunState`; present only while an STS Run is out
  (`src/run/RunManager.java:33-40`, set `:59`, unset `:135`).
- `$sts_home_fleet` (sector memory): the detached real player fleet while a Run is out
  (`src/run/HomeFleet.java:21-23`, set `:35`, unset `:59`).
- `$sts_battle`, `$sts_target` (enemy fleet memory), `$sts_node_id` (node entity memory): Run
  internals, not on the station.

Other ids: campaign plugin id `sts_campaign_plugin` (`STSConstants.java:52`), pocket system name
`The Descent` (`STSConstants.java:37`), factions `sts_descent` / `sts_ally` (`:47-49`).

**Detecting the station from another mod**, in order of robustness:
`Global.getSector().getEntityById("sts_hub")` (what STS itself does), or
`sector.getEntitiesWithTag("sts_hub")` per location, or custom entity type `sts_hub_station`.

## 2. Creation and placement

- **Hook.** Only `onGameLoad(boolean newGame)` (`src/SlayTheSectorModPlugin.java:46`), which calls
  `HubPlacer.ensureHub()` every load (`:74`). No `onNewGame`, `onNewGameAfterEconomyLoad`,
  `onNewGameAfterTimePass` or `SectorGeneratorPlugin`; no `data/campaign/` folder exists (so no
  `rules.csv`, no world-gen script). Placing on load is what makes it work in saves that predate
  the mod (`src/world/HubPlacer.java:18`).
- **Idempotency.** `ensureHub()` returns the existing entity if `getEntityById("sts_hub")` is
  non-null, only re-adding the intel (`src/world/HubPlacer.java:25-34`). The id is the only
  guard: an entity with a different id/type (e.g. one made by another mod) is not seen.
- **System choice.** `pickSystem()` sums `market.getSize()` of every non-hidden market per star
  system and takes the heaviest (`src/world/HubPlacer.java:70-87`). Vanilla sector: in practice a
  core world system; random sector: still works. Ties are broken by `HashMap` iteration order
  (non-deterministic). Returns null (and the Relay is not placed, warning logged) when no
  populated system exists (`:36-40`).
- **Orbit.** Focus = the star, or the system center if starless (`:41`). `addCustomEntity("sts_hub",
  "Descent Relay", "sts_hub_station", NEUTRAL)` (`:42`), tag added (`:43`),
  `setCircularOrbit(focus, 45f, radius, 160f)` (`:45`). Radius from `freeOrbitRadius`: start at
  2600, step +300 until no planet orbit is within `planetRadius + 400` (`:51-68`, cap 20000).
- **Also called from** `RunManager.returnToHub()` (`src/run/RunManager.java:177-181`), which
  re-creates the Relay if it vanished, then jumps the player to it.
- **Intel.** `HubIntel.ensure()` adds one permanent, important intel entry per save
  (`src/intel/HubIntel.java:32-36`). It holds no world reference and looks the hub up by id each
  time (`:38-40`), with "Show on map" / "Lay in course" buttons (`:97-111`). Saved under the
  XStream alias `STS_HubIntel` (`src/SlayTheSectorModPlugin.java:40`).

## 3. Opening the dialog

- **No rules.csv.** Routing is a transient `BaseCampaignPlugin`, `RunCampaignPlugin`
  (`src/RunCampaignPlugin.java:21-31`), unregistered then re-registered on every load
  (`src/SlayTheSectorModPlugin.java:63-64`).
- `pickInteractionDialogPlugin(target)`: if `target.hasTag("sts_hub")` return
  `new PluginPick<>(new HubDialog(), PickPriority.MOD_SPECIFIC)` (`src/RunCampaignPlugin.java:34-38`).
  Same pattern for Node beacons with tag `sts_node` (`:39-41`).
- **API fact (priority).** `CampaignPlugin.PickPriority` order is CORE_GENERAL < MOD_GENERAL <
  CORE_SET < MOD_SET < CORE_SPECIFIC < MOD_SPECIFIC < HIGHEST; the javadoc says what gets picked
  "when multiple plugins have the same priority is undefined" and that HIGHEST "shouldn't be used
  without good reason" (API `com/fs/starfarer/api/campaign/CampaignPlugin.java:21-67`). So if
  Ghost Core Arena also answers MOD_SPECIFIC for the same entity, which dialog opens is undefined.
- Plugin id `sts_campaign_plugin`: registering another plugin with the same id would replace STS's
  (API `CampaignPlugin.java:69-73`: "new registrations will override prior ones").
- Same plugin also picks `RunBattleCreationPlugin` for fleets with `$sts_battle`
  (`src/RunCampaignPlugin.java:45-51`) and `RunRespawnDialog` when the Run fleet is wiped
  (`:53-59`).

## 4. HubDialog structure

`src/hub/HubDialog.java`, a plain `InteractionDialogPlugin`, not extensible:

- Options are a **private enum** `Opt` (`:41-44`) plus private option-data classes (`:46-56`).
  `getMemoryMap()` returns null (`:331`), so rules.csv / `FireAll` cannot add options either.
  No registry, event or callback lets another mod add an option.
- `init` prints the flavour line and calls `showMain()` (`:72-79`).
- `showMain()` (`:81-96`) has three states:
  - STS Run active (`$sts_run_state`): "Return to the Run", "Abandon the Run"; **no Leave**
    (the Run fleet must not roam the real sector, `:93`).
  - Home fleet stashed, no Run: "Recover your Home fleet" only.
  - Idle: "Begin a Run", "Records", "Leave" (ESC shortcut, `:322-325`).
- Begin flow: Archetypes (paged, 8 per page, `:98-112`) -> Ascension (`:115-129`) -> starting
  bonuses (`:132-154`) -> Starting pick card grid via `dialog.showCustomVisualDialog`
  (`:186-211`) -> `startRun` (`:213-229`) -> "Refit the Run fleet" (`showCore(REFIT, ...)`,
  `:282-288`) / "Jump into the Descent" (`descend()`, `:313-320`).
- `descend()`: ensure the Node entity, `dialog.dismiss()`, then `RunSystem.jump(from, at)`
  (`:313-320`); the jump is done only after dismissing (CLAUDE.md hard constraint: never
  relocate the fleet from inside an open dialog).
- "Leave" just calls `dialog.dismiss()` (`:307-309`).

## 5. ModRemoval behaviour

`src/ModRemoval.java`, ADR `docs/adr/0002-removable-from-a-save.md`.

- Triggered by setting `sts_prepareRemoval: true` (`data/config/settings.json:2`, read at
  `src/util/STSSettings.java:136-138`) on load (`src/SlayTheSectorModPlugin.java:50-60`), or by
  the console command `sts remove` (`src/debug/StsCommand.java:100-106`).
- Blocked while an STS Run is active or the Home fleet is stashed (`src/ModRemoval.java:33-37`).
- Removes: every intel whose class is in `com.slaythesector.` (`:44-50`); **every custom entity
  whose type starts with `sts_` in every location** except the Descent (`:55-62`), which includes
  the Relay; fleets of `sts_descent`/`sts_ally` (`:63-67`); the Descent system via
  `removeStarSystemNextFrame` (`:71-74`); every `$sts_` key in sector and player memory
  (`:76-77`, `:92-100`); and unregisters `sts_campaign_plugin` (`:79`).
- On a removal load, `onGameLoad` returns before `ensureHub()` (`src/SlayTheSectorModPlugin.java:53-56`),
  so the Relay is not re-made. With the setting off on a later load it comes back (ADR 0002,
  Consequences).
- ADR 0002 notes a missing entity spec is "expected to fail" on load: a save holding a
  `sts_hub_station` entity probably cannot load without some mod defining that type (not verified
  in game).

**Cross-mod consequence:** if the station is shared, STS's removal would delete it even while
Ghost Core Arena still uses it, because it matches by type prefix, not by owner.

## 6. The pocket battle system (RunSystem, "The Descent")

`src/world/RunSystem.java`, ADR `docs/adr/0001-run-in-contained-system.md`.

- Found by name: `Global.getSector().getStarSystem("The Descent")` (`:36-38`).
- Created lazily at Run start (`src/run/RunManager.java:61`), not at load: `createStarSystem`,
  background `background4.jpg`, `initNonStarCenter()`, tags `THEME_HIDDEN`,
  `SYSTEM_CUT_OFF_FROM_HYPER` (system and center), `DO_NOT_SHOW_STRANDED_DIALOG`, **no jump
  points** (`src/world/RunSystem.java:44-59`).
- `placeInBounds` moves it inside the sector bounds at the grid point farthest from every other
  system, so mods sizing the sector from its systems (MagicLib bounties) are not skewed
  (`:61-102`); also re-run on load for old saves (`src/SlayTheSectorModPlugin.java:75-76`).
- Wipes: `clear()` removes everything but the player and center, only at Run start (`:104-118`);
  `clearNodesAndFleets()` between Acts and on return (`:120-130`).
- Node beacons: custom entity `sts_node_marker`, tag `sts_node`, memory `$sts_node_id`, fixed
  location by column/depth (`:136-148`).
- **Transitions:** `jump(from, to)` = unpause + `doHyperspaceTransition(playerFleet, from,
  new JumpDestination(to, null), 1f)` (vanilla GateCMD pattern, `:159-165`). Called after the
  dialog is dismissed. Return: `RunManager.returnToHub()` (`src/run/RunManager.java:177-181`).
- **Fleet swap:** `HomeFleet.stash` replaces the player fleet object with the Run fleet via
  `setPlayerFleet`, holding the real fleet in `$sts_home_fleet` and removing it from its location
  (`src/run/HomeFleet.java:26-41`); `restore` reverses it (`:44-62`). `SafetyNetScript` restores a
  stashed fleet with no active Run on load (`src/run/SafetyNetScript.java:29-40`).
- While in the Descent, `RunWatchScript` keeps Transverse Jump on cooldown and enforces Run fleet
  rules (`src/world/RunWatchScript.java:64-79`).

### How battles start there

1. Node dialog opens via tag `sts_node` (`src/RunCampaignPlugin.java:39-41`).
2. `EncounterFactory.spawn` builds the enemy (`FleetFactoryV3`), and `prepare` sets
   `setNoAutoDespawn`, `MEMORY_KEY_NO_REP_IMPACT`, `MAKE_HOSTILE`, `MAKE_AGGRESSIVE`, max CR,
   adds it at the node's location, `setDoNotAdvanceAI(true)` (`src/combat/EncounterFactory.java:39-58`,
   `:167-184`). Escape/pursuit fights set `$sts_battle` (`:50-52`, `:64`).
3. `NodeDialog.engage` builds a `FIDConfig` (no comm link, no pull-in of allies/enemies/stations,
   no rep impact, no credit loot, `dismissOnLeave=false`, `:236-254`) and a
   `FleetInteractionDialogPluginImpl` subclass (`RunEncounterDialog`, `:258`), with a
   `BaseFIDDelegate` that disables objectives / forces fight-to-the-last for Bosses
   (`:261-268`), strips supplies/fuel from salvage (`:271-276`) and, in `notifyLeave`, reads
   win/loss from the `FleetEncounterContext`, despawns the enemy and hands the dialog back
   (`:279-305`). Then `dialog.setInteractionTarget(enemy); dialog.setPlugin(fid); fid.init(dialog)`
   (`src/nodes/NodeDialog.java:307-309`).
4. Escape/pursuit layouts: `RunBattleCreationPlugin` rebuilds the `BattleCreationContext` with the
   wanted `FleetGoal`s and calls vanilla `BattleCreationPluginImpl` (`src/combat/RunBattleCreationPlugin.java:24-52`).
5. Run factions: `RunFactions.apply()` re-sets `sts_descent` VENGEFUL to the player and
   `sts_ally` COOPERATIVE on load, Run start and before each fight (`src/run/RunFactions.java:19-27`).

## 7. What Ghost Core Arena could reuse

Both mods must stay standalone, so GCA cannot call STS classes; it can only reuse **data
conventions** and **copy patterns**:

- **Station identity:** creating the station with id `sts_hub`, type `sts_hub_station` and tag
  `sts_hub` makes current STS (unchanged) find it and skip creation (`HubPlacer.java:30-34`) and
  route its own dialog there (`RunCampaignPlugin.java:36`). GCA would then have to define
  `sts_hub_station` in its own `data/config/custom_entities.json` so the type exists when STS is
  absent. Starsector merges `custom_entities.json` across mods by key (general engine behaviour,
  not verified here); the two definitions should be identical. Conflict: GCA's CLAUDE.md requires
  the `gca_` prefix on every new id and its validator enforces it, so an `sts_` (or neutral) shared
  id needs an explicit exception.
- **Placement algorithm:** `pickSystem` + `freeOrbitRadius` (`HubPlacer.java:51-87`) is small and
  self-contained; copying it gives the same system choice (modulo HashMap tie order).
- **Pocket system recipe:** `RunSystem.ensure` + `placeInBounds` + `jump` (`RunSystem.java:44-102`,
  `:159-165`), if GCA fights away from the station.
- **Fleet swap:** `HomeFleet` (`src/run/HomeFleet.java`) plus `SafetyNetScript`, if GCA's Run also
  replaces the player fleet; note `getContainingLocation()` stays set after `removeEntity`
  (`HomeFleet.java:66`).
- **Battle start:** the `FIDConfig` + `FleetInteractionDialogPluginImpl` + `BaseFIDDelegate`
  recipe of `NodeDialog.engage` (`src/nodes/NodeDialog.java:224-310`) and `EncounterFactory.prepare`.
- **Removal:** ADR 0002 pattern (settings flag, blocker, strip by prefix, residue scanner).

Cross-mod state GCA must respect even without sharing code: while `$sts_run_state` or
`$sts_home_fleet` is set, the player fleet is an STS Run fleet and the real fleet is stashed, so
GCA must not start its own Run (or swap fleets) then; symmetric keys from GCA would be needed for
STS to do the same.

## 8. Changes STS would need so it never makes a second station

Every place that creates, finds, owns or removes the Relay:

1. `src/world/HubPlacer.java:25-27` `getHub()`: only `getEntityById("sts_hub")`. Needs to accept
   the shared station whatever mod made it (agreed id, tag, or a shared memory key).
2. `src/world/HubPlacer.java:29-49` `ensureHub()`: create only when no shared station exists; if
   it creates one, use the agreed shared id/type/tag so the other mod finds it.
3. `src/world/HubPlacer.java:70-87` `pickSystem()`: only matters if both mods may create; the
   choice should be identical or irrelevant (first creator wins).
4. `src/util/STSConstants.java:30,34,35`: `sts_`-prefixed id/tag/type; a shared, mod-neutral name
   may be wanted (renaming affects existing saves: old `sts_hub` entities would need migration).
5. `data/config/custom_entities.json:2-9`: the type must be defined identically by both mods (or
   a neutral type used).
6. `src/SlayTheSectorModPlugin.java:74`: calls `ensureHub()` on every load (mid-save install,
   either order); the second-installed mod must adopt, not duplicate.
7. `src/run/RunManager.java:177-181` `returnToHub()`: re-creates the station if missing; same rule.
8. `src/intel/HubIntel.java:38-40,127`: looks the hub up by `sts_hub`; also the intel text is
   STS-only ("The Descent awaits"), two mods would show two intel entries for one station.
9. `src/RunCampaignPlugin.java:34-38`: claims every `sts_hub`-tagged entity at MOD_SPECIFIC with
   `HubDialog`; with two mods claiming the same entity the pick is undefined (API
   `CampaignPlugin.java:21-27`). Needs a single owner of the dialog, or STS stepping aside when
   the shared menu is provided elsewhere.
10. `src/hub/HubDialog.java:81-96,307-309`: main menu has no extension point and "Leave" just
    dismisses; needs either an entry point another mod can call (open `HubDialog` as a
    sub-menu and get control back) or a way to add options.
11. `src/ModRemoval.java:55-62`: deletes every `sts_*` custom entity, i.e. the shared station,
    even if GCA still needs it. Needs to skip the station when another mod uses it, and
    `ModRemoval.blocker()` (`:33-37`) does not know about GCA Runs.
12. `scripts/save_residue.py` (ADR 0002): flags `sts_hub_station` as residue; must agree with
    rule 11.
13. `src/run/SafetyNetScript.java` / `HubDialog` "no Leave during a Run": should also consider a
    GCA Run in progress (refuse Begin a Run while GCA's fleet swap is active).

## 9. Hooks a second mod needs to add its own dialog options

Today there are none: `HubDialog` has a private option enum, null memory map, no rules.csv
(`src/hub/HubDialog.java:41-44,331`), and routing is a hard-coded tag check
(`src/RunCampaignPlugin.java:36`). Options available, for the grilling ticket to choose from:

- **(a) Shared front menu.** Whichever mod opens the station shows a top menu with one entry per
  installed mod ("Slay the Sector", "Ghost Core Arena", "Leave"); each mod's entry calls
  `dialog.setPlugin(theirDialog); theirDialog.init(dialog)`. Needs: a way to discover installed
  mods' entries without a compile dependency (e.g. `Global.getSettings().getModManager().isModEnabled(id)`
  plus reflection on a known class name, or a registry object stored in sector memory /
  `Global.getSector().getPersistentData()`), and STS's "Leave"/"Back" to return to that menu.
- **(b) STS as host with an extension point.** STS keeps the dialog and exposes an option
  registry other mods fill on load (in a transient, non-saved structure such as a static list or
  sector transient data). Requires STS changes at `HubDialog.showMain` and `optionSelected`.
- **(c) Priority override.** GCA answers `pickInteractionDialogPlugin` at `HIGHEST` for the
  station and wraps STS's `HubDialog` (instantiated by class name via reflection) behind a
  "Slay the Sector" option. Works with STS unchanged, but HIGHEST is discouraged by the API doc
  and STS's Leave dismisses the whole dialog.
- **(d) rules.csv.** Would require both dialogs to run through `RuleBasedInteractionDialogPluginImpl`
  and an `OpenInteractionDialog`-style command; STS currently uses none of this.

Whatever is picked must also cover the in-Run states: STS hides Leave and forces "Return to the
Run" while its Run is out (`HubDialog.java:83-86`), and the shared menu must not let the player
enter the other mod's Run with an STS Run fleet (and vice versa).
