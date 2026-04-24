#!/usr/bin/env bash
# Usage: ./scripts/bump_version.sh 1.2.3
# Updates MARKETING_VERSION and increments CURRENT_PROJECT_VERSION in project.pbxproj

set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"
PBXPROJ="Saunday.xcodeproj/project.pbxproj"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Error: version must be in format X.Y or X.Y.Z" >&2
  exit 1
fi

# Increment build number (max existing + 1)
CURRENT_BUILD=$(grep -o 'CURRENT_PROJECT_VERSION = [0-9]*' "$PBXPROJ" | head -1 | grep -o '[0-9]*$')
NEW_BUILD=$((CURRENT_BUILD + 1))

sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $NEW_BUILD/g" "$PBXPROJ"

echo "Bumped to version $VERSION (build $NEW_BUILD)"
