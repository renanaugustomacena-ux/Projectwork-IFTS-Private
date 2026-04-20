#!/usr/bin/env bash
# Bump app version in v1/VERSION + sync to all consumers.
#
# Usage:
#   ./scripts/bump_version.sh patch        # 1.0.0 -> 1.0.1
#   ./scripts/bump_version.sh minor        # 1.0.0 -> 1.1.0
#   ./scripts/bump_version.sh major        # 1.0.0 -> 2.0.0
#   ./scripts/bump_version.sh 1.2.3        # set esplicito
#
# NON committa automaticamente: mostra git status al termine per review.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

version_file="v1/VERSION"

if [[ ! -f "$version_file" ]]; then
    echo "ERROR: $version_file non trovato. Crea prima con echo '1.0.0' > $version_file" >&2
    exit 1
fi

current=$(tr -d '[:space:]' < "$version_file")

if [[ ! "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: $version_file non contiene semver X.Y.Z: '$current'" >&2
    exit 1
fi

IFS='.' read -r major minor patch <<< "$current"

case "${1:-}" in
    major)
        new="$((major + 1)).0.0"
        ;;
    minor)
        new="${major}.$((minor + 1)).0"
        ;;
    patch)
        new="${major}.${minor}.$((patch + 1))"
        ;;
    [0-9]*.[0-9]*.[0-9]*)
        new="$1"
        ;;
    "")
        echo "Usage: $0 patch|minor|major|X.Y.Z" >&2
        exit 2
        ;;
    *)
        echo "ERROR: argomento non valido '$1'. Usa: patch, minor, major, o X.Y.Z" >&2
        exit 2
        ;;
esac

if [[ ! "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: nuova versione non-semver: '$new'" >&2
    exit 1
fi

echo "Bumping v${current} -> v${new}"
printf '%s\n' "$new" > "$version_file"

python3 scripts/sync_version_to_presets.py "$new"

echo
echo "--- git status ---"
git status --short

echo
echo "Review the diff, then commit:"
echo "  git add -A && git commit -m \"chore(release): bump version to ${new}\""
