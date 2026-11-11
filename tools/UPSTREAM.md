# Vendored tools

`sslib.py`, `build_mod.py`, `validate_mod.py`, `log_scan.py`, `package_mod.py` are copied verbatim from
[tracesfx/starsector-modding-skill](https://github.com/tracesfx/starsector-modding-skill) `scripts/`
at commit `ee66319fb25ad31543e56a918183617e4a3c7df6`. They need only Python 3 (no numpy/Pillow).

Do not edit them here; local config lives in `validate_config.json`. To update, re-copy from the
skill (installed at `~/.claude/skills/starsector-modding`) and bump the commit above.

| Command | Purpose |
|---|---|
| `./build.sh` | compile `src/` → `jars/GhostCoreArena.jar`, then validate (`--strict`, `--no-validate`) |
| `python3 tools/validate_mod.py --mod .` | static QA only |
| `python3 tools/log_scan.py --mod .` | triage `starsector.log` after an in-game test |
| `python3 tools/package_mod.py --strict` | release zip in `dist/` after release checks |
