#!/bin/sh
set -euo pipefail

PLIST="$CI_PRIMARY_REPOSITORY_PATH/App/FeatureKeys.plist"
PREFIX="FEATURE_KEY_"

matching=$(env | grep -E "^${PREFIX}" || true)

if [ -z "$matching" ]; then
    echo "No ${PREFIX}* env vars set; FeatureKeys.plist remains empty."
    exit 0
fi

echo "$matching" | while IFS='=' read -r name value; do
    key="${name#${PREFIX}}"
    plutil -insert "$key" -string "$value" "$PLIST"
    echo "Created $key in FeatureKeys.plist"
done
