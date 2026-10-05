#!/bin/zsh
# Captures fresh Mac App Store screenshots into Raw/Mac/<lang>/.
#
#   ./capture-mac.sh                  every language
#   ./capture-mac.sh --languages en   only English
#   ./capture-mac.sh --skip-build     reuse the last build
#
# Each window is opened at an exact size in points on a Retina display, and is checked to
# have come out at twice that in pixels, so ./compose.sh can lay it on the desktop without
# resampling. The app runs from its own sandbox container, filled with the sample library
# in Seed/, so nothing is fetched and your own library is left alone.
#
# The terminal running this needs Screen Recording access, and the Mac needs a Retina
# display awake. Keep the mouse and keyboard still while it runs: each window is brought
# to the front to be captured.
set -euo pipefail

assets_dir=${0:A:h}
repo_dir=${assets_dir:h:h}
source "$assets_dir/Capture/content.sh"
source "$assets_dir/Capture/mac.sh"
source "$assets_dir/Capture/scenes-mac.sh"

languages=(en ja)
skip_build=false
while (( $# > 0 )); do
    case $1 in
        --languages) languages=(${(s:,:)2}); shift 2 ;;
        --skip-build) skip_build=true; shift ;;
        *) print -u2 "unknown option: $1"; exit 64 ;;
    esac
done

build_dir=${TMPDIR:-/tmp}/sakura-capture-mac-build
built_app=$build_dir/Build/Products/Debug/Sakura.app
app_path=${TMPDIR:-/tmp}/sakura-capture-mac/Sakura.app
# Debug, for the launch arguments that set up each window; on the Mac it draws no
# layout overlays.
if ! $skip_build || [[ ! -d $built_app ]]; then
    step "Building Sakura for Mac"
    xcodebuild -project "$repo_dir/SakuraRSS.xcodeproj" -scheme "Sakura for Mac" -configuration Debug \
        -destination 'generic/platform=macOS' -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO \
        build > "$build_dir.log" 2>&1 || { print -u2 "build failed, see $build_dir.log"; exit 1; }
fi
quit_app
trap quit_app EXIT
prepare_app "$built_app"
create_database

for language in $languages; do
    step "Mac ($language)"
    seed_mac_library "$language"
    capture_mac_scenes "$language" "$assets_dir/Raw/Mac/$language"
done

step "Done. Run ./compose.sh to lay out the screenshots."
