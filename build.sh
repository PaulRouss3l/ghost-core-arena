#!/usr/bin/env bash
# One-command build: compile src/ -> jars/GhostCoreArena.jar -> validate. Non-zero exit on any error.
#   ./build.sh                 build + validate
#   ./build.sh --no-validate   compile only
#   ./build.sh --strict        warnings fail too (run before a release)
# Tools are vendored from the starsector-modding skill; see tools/UPSTREAM.md.
set -euo pipefail
cd "$(dirname "$0")"
export STARSECTOR_DIR="${STARSECTOR_DIR:-/home/ubik/Downloads/starsector}"
exec python3 tools/build_mod.py "$@"
