#!/bin/sh
set -euo pipefail

PLIST="$CI_PRIMARY_REPOSITORY_PATH/App/FeatureKeys.plist"
PREFIX="FEATURE_KEY_"

matching=$(env | grep -E "^${PREFIX}" || true)

if [ -z "$matching" ]; then
    echo "No ${PREFIX}* env vars set; FeatureKeys.plist remains empty."
else
    echo "$matching" | while IFS='=' read -r name value; do
        key="${name#${PREFIX}}"
        plutil -insert "$key" -string "$value" "$PLIST"
        echo "Created $key in FeatureKeys.plist"
    done
fi

ADDRESS_FILE="$CI_PRIMARY_REPOSITORY_PATH/Hanami/Sakura Cloud/SakuraCloudAddress.swift"

if [ -z "${SAKURA_CLOUD_URL:-}" ]; then
    echo "SAKURA_CLOUD_URL is not set; content refinement with SakuraCloud is off in this build."
    exit 0
fi

case "$SAKURA_CLOUD_URL" in
    https://*) ;;
    *) echo "error: SAKURA_CLOUD_URL must start with https://"; exit 1 ;;
esac

case "$SAKURA_CLOUD_URL" in
    *\"* | *\\* | *\|*) echo "error: SAKURA_CLOUD_URL must not contain quotes, backslashes, or pipes"; exit 1 ;;
esac

sed -i '' "s|static let url = \"\"|static let url = \"$SAKURA_CLOUD_URL\"|" "$ADDRESS_FILE"
grep -q "static let url = \"$SAKURA_CLOUD_URL\"" "$ADDRESS_FILE"
echo "Wrote SAKURA_CLOUD_URL into SakuraCloudAddress.swift"
