# Developing Ghost Core Arena

A VSCode port of the [Starsector IntelliJ template](https://github.com/wispborne/Starsector-IntelliJ-Template),
adapted for **Linux** and Starsector **0.98a** (bundled Zulu JDK 17).

> **Project context & design**: see [`CLAUDE.md`](../CLAUDE.md) and the other files in this folder
> ([DESIGN](DESIGN.md), [ROADMAP](ROADMAP.md), [API_NOTES](API_NOTES.md)).

## Prerequisites (one-time)

1. **JDK 17** (the game ships a JRE only — no compiler):
   ```sh
   sudo apt install openjdk-17-jdk
   ```
   Confirm the path matches `.vscode/settings.json`:
   ```sh
   readlink -f $(which javac)   # expect /usr/lib/jvm/java-17-openjdk-amd64/...
   ```
2. **VSCode extensions**: `redhat.java` + `vscjava.vscode-java-debug`
   (VSCode prompts to install them from `.vscode/extensions.json`).
3. **Symlink the project into the game's `mods/`** so the launcher loads it:
   ```sh
   ln -s /home/ubik/localhost/perso/starsector/ghost-core-arena \
         /home/ubik/Downloads/starsector/mods/ghost-core-arena
   ```

## Layout

| Path | Purpose |
|------|---------|
| `mod_info.json` | Mod metadata; `modPlugin` points at the entry class |
| `src/com/ghostcorearena/` | Java sources |
| `jars/GhostCoreArena.jar` | Build output (referenced by `mod_info.json`) |
| `build.sh` | Compile `src/` → `jars/GhostCoreArena.jar`, then validate (`--strict` for releases) |
| `tools/` | Build/validate/log-scan/package scripts vendored from the starsector-modding skill (`tools/UPSTREAM.md`) |
| `ghost_core_arena.version` | Version Checker file (hosted raw from GitHub `main`) |
| `run.sh` | Launch the game from the install dir with a debug agent on `:5005` |
| `.vscode/settings.json` | Wires game jars for IntelliSense (API autocomplete + javadoc) |
| `.vscode/tasks.json` | "Build mod" and "Run Starsector" tasks |
| `.vscode/launch.json` | "Debug Starsector" — build, launch, attach debugger |

## Workflow

- **Build only:** `Ctrl+Shift+B`, or `./build.sh` (needs `python3` + JDK 17).
- **Run with debugging:** Run panel → **Debug Starsector** (F5). Builds, launches
  the game, attaches to `:5005`. Set breakpoints in `src/` and they hit.
- **Run without debugging:** `./run.sh`. It renders on the NVIDIA card (PRIME offload) because the Intel
  iGPU hangs the desktop; `GCA_IGPU=1 ./run.sh` keeps the iGPU.

## Adjusting paths

`gameVersion` in `mod_info.json` is `0.98a-RC8` (the installed version). If the launcher shows a
"version mismatch" warning, set it to the exact version printed on the launcher screen.

## Release

Built locally on purpose: compiling needs the game's own jars, which can't go to a public CI.

1. On a branch: bump the version in `mod_info.json`, `ghost_core_arena.version` and `CHANGELOG.md`
   (a `## X.Y.Z` section), and point `directDownloadURL` in `ghost_core_arena.version` at
   `releases/download/vX.Y.Z/ghost-core-arena-X.Y.Z.zip`. Version Checker, TriOS and the README's
   TriOS badge read that file from `main`, so they follow the newest release once it is merged.
2. Check without publishing: `./release.sh X.Y.Z --dry-run` (any branch).
3. Merge to `main`, pull, then `./release.sh X.Y.Z` (add `--prerelease` for a beta). It refuses
   unless it is on `main`, clean and in sync with origin, the tag is new and every version matches;
   then it runs the strict build and package, tags `vX.Y.Z`, pushes the tag and creates the GitHub
   release with the zip and this version's CHANGELOG section as notes. Set `GCA_GH_USER` to pick
   the gh account.
4. After an in-game test: `python3 tools/log_scan.py --mod .`.
