#!/usr/bin/env bash
# Release Ghost Core Arena: checks, strict build, strict package, tag, GitHub release with the zip.
#
#   ./release.sh 0.5.0                # full release from main
#   ./release.sh 0.5.0 --prerelease   # same, marked as a pre-release on GitHub
#   ./release.sh 0.5.0 --dry-run      # checks + build + zip only (any branch); no tag, no release
#
# Built locally on purpose: compiling needs the game's own jars, which can't go to CI.
# Needs: python3, JDK 17, gh (logged in; set GCA_GH_USER to pick an account), the game
# (STARSECTOR_DIR, default /home/ubik/Downloads/starsector).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
PRERELEASE=""
DRY_RUN=""
for arg in "${@:2}"; do
    case "$arg" in
        --prerelease) PRERELEASE="--prerelease" ;;
        --dry-run) DRY_RUN=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: ./release.sh X.Y.Z [--prerelease] [--dry-run]" >&2
    exit 2
fi
TAG="v$VERSION"
ZIP="dist/ghost-core-arena-$VERSION.zip"
REPO="PaulRouss3l/ghost-core-arena"
export STARSECTOR_DIR="${STARSECTOR_DIR:-/home/ubik/Downloads/starsector}"
if [[ -n "${GCA_GH_USER:-}" ]]; then
    GH_TOKEN="$(gh auth token --user "$GCA_GH_USER")"
    export GH_TOKEN
fi
fail() { echo "RELEASE ERROR: $*" >&2; exit 1; }
step() { echo "==> $*"; }

step "Checking the repository"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ -z "$(git status --porcelain)" ]] || fail "the working tree has uncommitted changes"
if [[ -z "$DRY_RUN" ]]; then
    [[ "$BRANCH" == "main" ]] || fail "release from main (current branch: $BRANCH)"
    git -c credential.helper= -c 'credential.helper=!gh auth git-credential' fetch -q origin main
    [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "main is not in sync with origin/main"
    git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && fail "tag $TAG already exists"
fi

step "Checking version $VERSION in mod_info.json, ghost_core_arena.version and CHANGELOG.md"
python3 - "$VERSION" <<'PY' || fail "version check failed (see above)"
import json, re, sys
v = sys.argv[1]
major, minor, patch = v.split(".")
errors = []
info = json.loads(re.sub(r"#.*", "", open("mod_info.json").read()))
mv = info["version"]
if [str(mv.get("major")), str(mv.get("minor")), str(mv.get("patch"))] != [major, minor, patch]:
    errors.append("mod_info.json version is %s.%s.%s" % (mv.get("major"), mv.get("minor"), mv.get("patch")))
ver = json.load(open("ghost_core_arena.version"))
vv = ver["modVersion"]
if [str(vv.get("major")), str(vv.get("minor")), str(vv.get("patch"))] != [major, minor, patch]:
    errors.append(".version modVersion is %s.%s.%s" % (vv.get("major"), vv.get("minor"), vv.get("patch")))
want = "/releases/download/v%s/ghost-core-arena-%s.zip" % (v, v)
if want not in ver.get("directDownloadURL", ""):
    errors.append(".version directDownloadURL should end with " + want)
if not re.search(r"^## %s\b" % re.escape(v), open("CHANGELOG.md").read(), re.M):
    errors.append("CHANGELOG.md has no '## %s' section" % v)
for e in errors:
    print("  - " + e)
sys.exit(1 if errors else 0)
PY

step "Strict build"
./build.sh --strict

step "Strict package"
python3 tools/package_mod.py --strict
[[ -f "$ZIP" ]] || fail "$ZIP was not produced"

NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT
# Release notes: this version's CHANGELOG section, without its heading.
awk -v v="$VERSION" '
    $0 ~ "^## " v "([^0-9.]|$)" { on = 1; next }
    on && /^## / { exit }
    on { print }
' CHANGELOG.md > "$NOTES"

if [[ -n "$DRY_RUN" ]]; then
    step "Dry run: would tag $TAG and publish $ZIP${PRERELEASE:+ (pre-release)} to $REPO with these notes:"
    cat "$NOTES"
    exit 0
fi

step "Tagging $TAG"
git tag -a "$TAG" -m "Ghost Core Arena $VERSION"
git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push -q origin "$TAG"

step "Creating the GitHub release"
gh release create "$TAG" "$ZIP" --repo "$REPO" --title "Ghost Core Arena $VERSION" --notes-file "$NOTES" $PRERELEASE

echo "Released $TAG: https://github.com/$REPO/releases/tag/$TAG"
