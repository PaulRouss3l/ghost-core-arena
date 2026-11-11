# Research: what a Ghost Fleet snapshot must hold to respawn exactly

Ticket: #4. Game: Starsector 0.98a-RC8. Every API signature below was checked with
`~/.claude/skills/starsector-modding/scripts/api_lookup.py` (`javap` against `starfarer.api.jar`,
`method`/`grep` against the `starfarer.api.zip` sources). Some facts come from disassembling the
**non-API** class `com.fs.starfarer.loading.specs.HullVariantSpec` in `starfarer_obf.jar` with `javap -c`;
they are marked **(obf bytecode)**. Facts not checked in a running game are marked **(unverified in game)**.

## TL;DR

- Do **not** ship a stock variant id. A Run ship stops being stock once it is merged, S-modded or
  refitted. Serialize the **full variant**, field by field, from the public `ShipVariantAPI` getters,
  and rebuild it on `Global.getSettings().createEmptyVariant(id, hullSpec)` with the public setters.
  This is what MagicLib's `MagicCampaign.loadVariant` does (bytecode inspected), and it needs no
  non-API class.
- `ShipVariantAPI.toJSONObject()` exists and writes the `.variant` file format, but it **drops**
  `sModdedBuiltIns`, `suppressedMods`, weapons that are in no weapon group, and refitted module
  variants (it writes module **ids** only). There is **no public reverse** (`fromJSON`). Use it for
  debug dumps only, or as a base that you then extend.
- Officers: personality id, level, every non-aptitude skill with level 1 or 2 (2 = elite), portrait
  path, name and gender. Rebuild with `Global.getFactory().createPerson()` + `getStats().setSkillLevel`.
- Flagship: an index into the ship list, plus the captain of that ship (the Run's player character).
- Mod-set fingerprint: `Global.getSettings().getModManager().getEnabledModsCopy()` → sorted
  `id@version` pairs, plus `Global.getSettings().getGameVersion()`, hashed.

## 1. JSON schema (proposal)

```jsonc
{
  "schema": 1,
  "gameVersion": "0.98a-RC8",          // SettingsAPI.getGameVersion()
  "modSet": "sha256:…",                // fingerprint, section 5
  "mods": [["ghost_core_arena","0.0.1"], ["lw_lazylib","3.0.0"], …],  // kept for diagnostics
  "cycle": 4,
  "factionId": "hegemony",             // the Run's faction (cosmetic / doctrine, see pitfalls)
  "flagship": 0,                       // index into "ships"
  "commander": { /* person, same shape as "captain"; the Run's player character */ },
  "ships": [
    {
      "star": 2,                       // Star Level (mod data, not an API field)
      "name": "ISS Example",           // FleetMemberAPI.getShipName(), cosmetic
      "variant": {
        "hullId": "eagle",             // getHullSpec().getHullId()  (may be a D-hull, "eagle_default_D")
        "variantId": "gca_ghost_…",    // unique, generated at rebuild time; stored only for debugging
        "originalVariant": "eagle_Assault", // getOriginalVariant(), nullable, informational
        "displayName": "Assault",
        "vents": 20, "caps": 10,       // getNumFluxVents / getNumFluxCapacitors
        "weapons": { "WS0001": "heavymauler", … }, // non-built-in slots only, see 2.1
        "groups": [ { "mode": "LINKED", "autofire": false, "slots": ["WS0001","WS0002"] } ],
        "wings": [ "broadsword_wing", null ],      // by bay index, see 2.1
        "hullMods": ["heavyarmor", "hardenedshieldemitter"], // getNonBuiltInHullmods()
        "permaMods": ["heavyarmor", "degraded_engines"],     // getPermaMods() (S-mods + D-mods)
        "sMods": ["heavyarmor"],                             // getSMods()
        "sModdedBuiltIns": [],                               // getSModdedBuiltIns()
        "suppressedMods": [],                                // getSuppressedMods()
        "tags": ["gca_star_2"],                              // getTags()
        "modules": { "WS0010": { /* nested "variant" object, same shape */ } } // modular ships only
      },
      "captain": null | {
        "aiCore": null,                // getAICoreId(); null for human officers
        "first": "Ada", "last": "Vance", "gender": "FEMALE",  // FullName
        "portrait": "graphics/portraits/portrait_hegemony05.png",
        "personality": "aggressive",   // getPersonalityAPI().getId()
        "level": 2,                    // getStats().getLevel()
        "skills": { "helmsmanship": 2, "target_analysis": 1 }  // level 2 = elite
      }
    }
  ]
}
```

What is **not** in the snapshot, on purpose: fleet member ids, CR, hull/armor damage, XP, crew,
supplies. The Ghost Fleet always fights at full CR and full repair (rebuild sets them).

## 2. Ships

### 2.1 Serialize (all public `ShipVariantAPI` / `FleetMemberAPI` methods, javap-verified)

| Field | Call |
|---|---|
| hull | `variant.getHullSpec().getHullId()`. Keep the D-hull id as is (`Misc.D_HULL_SUFFIX = "_default_D"`, `ShipHullSpecAPI.isDefaultDHull()`); `getHullSpec(dHullId)` is how vanilla `DModManager.setDHull` reaches it. |
| vents / caps | `getNumFluxVents()`, `getNumFluxCapacitors()` |
| weapons | for `slot` in `getNonBuiltInWeaponSlots()`: `getWeaponId(slot)` (skip null). Built-in weapons come back with the hull. `getFittedWeaponSlots()` skips decorative slots **(obf bytecode)** but includes built-ins. |
| weapon groups | `getWeaponGroups()` → `WeaponGroupSpec.getType()` (`WeaponGroupType` enum), `isAutofireOnByDefault()`, `getSlots()`. Cosmetic for the AI (it regroups), but cheap. |
| wings | `getWings()` is the live `wings` list by bay index **(obf bytecode)**; `getWingId(i)`; `getNonBuiltInWings()` filters out the hull's `getBuiltInWings()` by index. Store the full list by index, write back only non-built-in indices. |
| hullmods | `getNonBuiltInHullmods()` (built-ins come back with the hull) |
| S-mods | `getSMods()` (added with `addPermaMod(id, true)`) |
| D-mods | `getPermaMods()` minus `getSMods()` (vanilla `DModManager` adds them with `addPermaMod(id, false)`) |
| S-modded built-ins | `getSModdedBuiltIns()` (0.98 feature; read by `BaseHullMod.isSMod`, `Misc`) |
| suppressed mods | `getSuppressedMods()` |
| tags | `getTags()` (some mods keep per-ship state here) |
| modules | `getModuleSlots()` + `getModuleVariant(slot)` → recurse; `getStationModules()` gives slot → variant id |
| name | `FleetMemberAPI.getShipName()` |
| captain | `FleetMemberAPI.getCaptain()`; skip when `captain.isDefault()` (unofficered ship) |
| flagship | `FleetMemberAPI.isFlagship()` / `fleet.getFlagship()` |

### 2.2 Rebuild

```java
ShipHullSpecAPI hull = Global.getSettings().getHullSpec(s.hullId);
ShipVariantAPI v = Global.getSettings().createEmptyVariant("gca_ghost_" + uid, hull); // carries built-ins
v.setSource(VariantSource.REFIT);              // never let it look stock
v.setNumFluxVents(s.vents); v.setNumFluxCapacitors(s.caps);
for (slot, w) : s.weapons -> v.addWeapon(slot, w);
for (i, wing) : s.wings   -> if (wing != null && i >= hull.getBuiltInWings().size()) v.setWingId(i, wing);
for (m) : s.hullMods      -> if (!v.hasHullMod(m)) v.addMod(m);
for (m) : s.sMods         -> v.addPermaMod(m, true);
for (m) : dMods           -> v.addPermaMod(m, false);
v.getSModdedBuiltIns().addAll(s.sModdedBuiltIns);   // live set (obf bytecode), no setter exists
for (m) : s.suppressedMods -> v.addSuppressedMod(m);
for (t) : s.tags          -> v.addTag(t);
for (g) : s.groups        -> { WeaponGroupSpec gs = new WeaponGroupSpec(WeaponGroupType.valueOf(g.mode));
                               gs.setAutofireOnByDefault(g.autofire); g.slots.forEach(gs::addSlot);
                               v.addWeaponGroup(gs); }
if (s.groups.isEmpty()) v.autoGenerateWeaponGroups();
for (slot, mv) : s.modules -> v.setModuleVariant(slot, rebuild(mv));
FleetMemberAPI m = Global.getFactory().createFleetMember(FleetMemberType.SHIP, v);
m.setShipName(s.name);
```

Then, after all members are in the fleet: `fleet.forceSync()`, for each member `updateStats()` and
`getRepairTracker().setCR(getRepairTracker().getMaxCR())`, as vanilla `FleetFactoryV3.createFleet`
(lines 486-494) and Slay the Sector's `EncounterFactory.prepare` do. Order of `addMod` vs
`addPermaMod`: MagicLib adds perma mods first, then `addMod` only if `!getHullMods().contains(id)`;
either order works if you guard with `hasHullMod` **(unverified in game)**.

The wing index rule (`i >= builtInWings.size()`) mirrors `getNonBuiltInWings()` **(obf bytecode)**;
verify on a carrier with a built-in wing (e.g. a Drover-style hull) **(unverified in game)**.

### 2.3 `toJSONObject()` and the game's own variant reader

- `ShipVariantAPI.toJSONObject()` is public API (javap). Vanilla uses it once, in
  `CodexDataV2` line 1342, to compare module variants as strings.
- **(obf bytecode)** It writes: `displayName, hullId, variantId, fluxVents, fluxCapacitors,
  goalVariant, weaponGroups[{mode, autofire, weapons{slot: weaponId}}], modules[{slot: variantId}]
  (from stationModules), wings, hullMods, permaMods, sMods, tags`.
  It does **not** write `sModdedBuiltIns` or `suppressedMods`, writes weapons **only inside weapon
  groups** (a weapon in no group is lost: call `assignUnassignedWeapons()` first), and writes
  modules as variant **ids**, so a refitted module comes back stock.
- The game's reader is the constructor `HullVariantSpec(JSONObject)` in `starfarer_obf.jar` **(obf
  bytecode)**; it reads `sModdedBuiltIns` and `suppressedMods` too. It is not API: obfuscated,
  renamable in any patch. Do not call it.
- The refit screen's "save variant" writer is not exposed in the API (no `SettingsAPI` method writes
  a variant); nothing found to reuse.
- Practical choice: own schema (section 1), written with the public getters. `toJSONObject()` is
  fine for a `[GhostCoreArena]` debug dump next to the snapshot.

### 2.4 Pitfalls

- **Stock vs custom.** `isStockVariant()`, `getSource()` (`VariantSource`: `STOCK, MISSION_DESIGN,
  MISSION_SAVE, REFIT, HULL`). Fleet members built from a variant id share the stock object: always
  `clone()` + `setSource(VariantSource.REFIT)` before changing one (skill api-notes, "Boss fleets";
  Slay the Sector `RunFleet.addShip`). A rebuilt variant from `createEmptyVariant` is fresh, but set
  `REFIT` anyway.
- **Variant id must be unique** per rebuilt ship (`gca_ghost_<snapshot>_<i>`); never reuse a stock id
  (`Global.getSettings().doesVariantExist(id)` to check).
- **D-hulls.** A ship with D-mods has the D-hull spec (`*_default_D`). Store that hull id; rebuilding
  on the base hull and adding D-mods alone gives the wrong spec (D-hull sprite/stats).
- **Modules / stations.** `getModuleVariant(slot)` / `setModuleVariant(slot, v)` exist; recurse.
  `toJSONObject()` loses module refits.
- **Fleet inflater.** `FleetFactoryV3.createEmptyFleet` (source lines 1315-1339) calls
  `Global.getFactory().createEmptyFleet(...)` and sets **no inflater**; only `createFleet` does
  (`fleet.setInflater(Misc.getInflater(...))`, line 487). Build Ghost Fleets on an empty fleet and
  never call `setInflater` with a `DefaultFleetInflater`, or autofit/`inflateIfNeeded()` re-rolls
  weapons. Defensive: `fleet.setInflater(null)` (vanilla does this in `NGCAddStandardStartingScript`,
  `PKDefenderPluginImpl`). Also unset `MemFlags.MEMORY_KEY_FLEET_TYPE` if the type is null (Slay the
  Sector `RunFleet.create`: Combat Chatter crashed on it).
- **Missing content.** Same mod set is enforced, but still validate before rebuilding:
  `getHullSpec`, `getHullModSpec`, `getWeaponSpec`, `getFighterWingSpec`, `getSkillSpec` return
  types are javap-verified; whether they return null or throw on an unknown id is **unverified**.
  Build `Set<String>`s from `getAllShipHullSpecs()`, `getAllHullModSpecs()`, `getAllWeaponSpecs()`,
  `getAllFighterWingSpecs()`, `getSkillIds()` once and reject the whole snapshot on any unknown id.
- **Hullmods from other mods** that hold state outside the variant (per-member data keyed by
  `FleetMemberAPI.getId()`, e.g. Exotica Technologies' exotics/upgrades, Second-in-Command
  executive officers) are **not** captured. The variant still carries their hidden hullmod ids, so
  the ship may rebuild with the hullmod but without its data **(unverified in game)**. Either strip
  hullmods whose spec is hidden and not from a known whitelist, or accept the mismatch; decide in
  design. Mods also add hidden built-in hullmods at runtime: `getNonBuiltInHullmods()` avoids
  copying those as regular mods.
- **Tags** may contain mod-internal markers (e.g. `variant_always_retain_smods_on_salvage`,
  which MagicLib adds). Harmless; keep them.
- **OP limits** are not re-checked by the API on `addWeapon`/`addMod`; the rebuild is exact even if
  the receiving player's skills would give a different OP budget. Good for exactness.

## 3. Officers (captains of merged ships, and the commander)

### 3.1 Serialize

| Field | Call (javap-verified) |
|---|---|
| AI core | `PersonAPI.isAICore()`, `getAICoreId()` |
| name | `getName()` → `FullName.getFirst()/getLast()/getGender()` (`FullName.Gender` enum) |
| portrait | `getPortraitSprite()` (a sprite path; same mod set, so mod portraits resolve) |
| personality | `getPersonalityAPI().getId()` → one of `Personalities.TIMID, CAUTIOUS, STEADY, AGGRESSIVE, RECKLESS` (`"timid"` … `"reckless"`) |
| level | `getStats().getLevel()` |
| skills | `getStats().getSkillsCopy()` → `SkillLevelAPI.getSkill().getId()`, `getLevel()`; skip `getSkill().isAptitudeEffect()` (vanilla `OfficerManagerEvent` line 595, `SkillData`) and level ≤ 0 |
| elite | skill level ≥ 2 (vanilla `Misc.getNumEliteSkills`: `sl.getLevel() >= 2`; `CyberneticAugmentation`: `getLevel() >= 2f && getSkill().isElite()`) |

`OfficerDataAPI` (`getPerson`, `getSkillPicks`, `addXP`, `levelUp`, `makeSkillPicks`) is the
player-fleet level-up bookkeeping. A Ghost Fleet does not need it: AI fleets give a captain to the
member only (`FleetFactoryV3` line 1097: `member.setCaptain(person)`; `fleetData.addOfficer(person)`
only when the commander is the player, line 1100).

### 3.2 Rebuild

```java
PersonAPI p = Global.getFactory().createPerson();
p.setFaction(ghostFactionId);
p.setName(new FullName(c.first, c.last, FullName.Gender.valueOf(c.gender)));
p.setPortraitSprite(c.portrait);
p.setPersonality(c.personality);
p.setRankId(Ranks.SPACE_LIEUTENANT); p.setPostId(Ranks.POST_OFFICER);   // as createOfficer does
p.getStats().setSkipRefresh(true);
p.getStats().setLevel(c.level);
for (id, lvl) : c.skills -> p.getStats().setSkillLevel(id, lvl);      // 2 = elite
p.getStats().setSkipRefresh(false);
p.getStats().refreshCharacterStatsEffects();
if (c.aiCore != null) p.setAICoreId(c.aiCore);
member.setCaptain(p);
```

`setSkipRefresh` / `refreshCharacterStatsEffects` mirror `OfficerManagerEvent.createOfficer`
(0.98a source). `setLevel(int)` and `setSkillLevel(String, float)` are on
`MutableCharacterStatsAPI` (javap). Level is display/limit data; the skills are what count in combat.

### 3.3 Pitfalls

- **Unofficered ships.** `member.getCaptain().isDefault()` is true. Their combat personality is not
  stored on the ship: it comes from the owning faction's doctrine (`FactionDoctrineAPI.getAggression()`,
  read by `FactionPersonalityPickerPluginImpl`) **(unverified in game which of the two the combat AI
  reads for default captains)**. To keep it identical across players, spawn every Ghost Fleet under one
  `gca_` faction with a fixed doctrine aggression, and do the same for the player's Run fleet, or
  store the owner's aggression and accept that a shared faction can only hold one value at a time.
- **Personality TIMID**: vanilla `FleetFactoryV3` silently turns timid officers into cautious. Our
  rebuild sets the stored id directly, so it stays exact.
- **The commander / flagship captain** is the Run's player character. Its combat skills fly the
  flagship and its admiral (fleet-wide) skills buff the whole fleet. Snapshot it like an officer
  (same shape, plus admiral skills: `SkillSpecAPI.isAdmiralSkill()`), then `fleet.setCommander(p)`,
  `flagshipMember.setCaptain(p)`, `fleet.getFleetData().setFlagship(flagshipMember)` (FleetFactoryV3
  lines 1043-1047). Whether to include admiral skills is a design call (they could make two Ghost
  Fleets with identical ships play very differently); leaving them out still respawns the ships exactly.
- Do not use `OfficerManagerEvent.createOfficer` to rebuild: it rolls random skills and personality.

## 4. Flagship

Store the index in `ships`. Rebuild: `fleet.getFleetData().setFlagship(member)` (javap) after the
member is added, with the commander as its captain. `FleetDataAPI.ensureHasFlagship()` exists as a
fallback. `FleetMemberAPI.setFlagship(boolean)` / `setFlagship(boolean, boolean)` also exist; vanilla
uses the `FleetDataAPI` route.

## 5. Mod-set fingerprint

```java
List<String> parts = new ArrayList<>();
for (ModSpecAPI s : Global.getSettings().getModManager().getEnabledModsCopy())
    parts.add(s.getId() + "@" + s.getVersion());
Collections.sort(parts);
String key = Global.getSettings().getGameVersion() + "|" + String.join(",", parts);
// fingerprint = sha256(key), hex  (java.security.MessageDigest; not file I/O)
```

- `ModManagerAPI` (javap): `getEnabledModsCopy()`, `getAvailableModsCopy()`, `isModEnabled(id)`,
  `getModSpec(id)`, `getEnabledModPlugins()`.
- `ModSpecAPI` (javap): `getId()`, `getName()`, `getVersion()` (String), `getVersionInfo()`
  (`VersionInfoAPI`: `getMajor/getMinor/getPatch/getString`), `isUtility()`, `getGameVersion()`,
  `getPath()`, `getJars()`, `getDependencies()`.
- `SettingsAPI.getGameVersion()` and `getVersionString()` both exist (javap); which string each
  returns is **unverified** (expected `0.98a-RC8`). Use `getGameVersion()`.
- Use `getVersion()` (the string the mod's `mod_info.json` declares; object-form versions like ours,
  `{major, minor, patch}`, should come back as `"0.0.1"`) **(unverified in game; log it once)**.
- Sort by id: the enabled-list order follows load order, not something two players share.
- A version string is only as good as the mod author's discipline: two builds of a mod with the same
  version but different ships would match. Hashing jar or data files is not an option: the script
  classloader rejects `java.io.File` and streams (skill api-notes, "Restricted APIs"). Accept it.
- Design choice left open: include utility mods (`isUtility()`, e.g. Combat Chatter, Console
  Commands) or not. They do not change ships, so excluding them widens matchmaking pools.

## 6. Local storage note

`SettingsAPI.writeJSONToCommon(String, JSONObject, boolean)` and `readJSONFromCommon(String, boolean)`
exist (javap): a sanctioned way to cache snapshots on disk without `java.io`. Networking (upload)
is outside this ticket; check separately whether `java.net` is allowed by the script classloader.

## Sources

- `starfarer.api.jar` (javap via `api_lookup.py javap`): `ShipVariantAPI`, `SettingsAPI`,
  `FactoryAPI`, `FleetMemberAPI`, `FleetDataAPI`, `CampaignFleetAPI`, `PersonAPI`,
  `MutableCharacterStatsAPI` (+`$SkillLevelAPI`), `OfficerDataAPI`, `PersonalityAPI`, `SkillSpecAPI`,
  `ModManagerAPI`, `ModSpecAPI`, `VersionInfoAPI`, `VariantSource`, `WeaponGroupSpec`,
  `ShipHullSpecAPI`, `FactionDoctrineAPI`.
- `starfarer.api.zip` sources: `FleetFactoryV3` (createEmptyFleet, createFleet, addCommanderAndOfficersV2),
  `OfficerManagerEvent.createOfficer`, `DModManager.setDHull`, `Misc.getNumEliteSkills`,
  `Misc.D_HULL_SUFFIX`, `CodexDataV2` line 1342, `Personalities`.
- `starfarer_obf.jar` `com.fs.starfarer.loading.specs.HullVariantSpec` (`javap -c`): `toJSONObject`
  keys, `HullVariantSpec(JSONObject)` keys, live-collection getters.
- MagicLib 1.5.6 `org.magiclib.util.MagicCampaign.loadVariant(String)` (`javap -c`): JSON →
  variant via public API.
- Slay the Sector `src/com/slaythesector/run/RunFleet.java`, `combat/EncounterFactory.java`.
- `~/.claude/skills/starsector-modding/references/api-notes.md` ("Boss fleets", "Swapping a fleet
  member's hull", "Restricted APIs").
