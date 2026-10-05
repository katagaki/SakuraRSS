# The Mac app's lifecycle for capture-mac.sh. Sourced, not run.
#
# The capture runs a Debug build re-signed ad hoc under its own bundle ID, sandboxed and
# without the app group, so its database and preferences live in a container of their own
# and the library of the Sakura you use every day is never touched.

bundle_id=com.tsubuzaki.SakuraRSS.MacCapture
container_data=~/Library/Containers/$bundle_id/Data
window_number_file=$container_data/tmp/capture-window-number

step() {
    print -P "%B==> $1%b"
}

group_container() {
    print "$container_data/Library/Application Support/SakuraRSS"
}

database() {
    sqlite3 "$(group_container)/Sakura.feeds" "$@"
}

# Copies the build out and signs the copy as the capture app.
prepare_app() {
    local built_app=$1 nested
    rm -rf "$app_path"
    mkdir -p "${app_path:h}"
    cp -R "$built_app" "$app_path"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$app_path/Contents/Info.plist"
    for nested in "$app_path"/Contents/Frameworks/*(N) "$app_path"/Contents/MacOS/*.dylib(N); do
        codesign --force --sign - "$nested" 2> /dev/null
    done
    codesign --force --sign - --entitlements "$assets_dir/Capture/capture.entitlements" "$app_path" 2> /dev/null
}

# By the end of the path only: $TMPDIR ends in a slash and resolves under /private,
# so the full path never matches the running process.
app_pids() {
    pgrep -f "${app_path:h:t}/Sakura.app/Contents/MacOS/Sakura" || true
}

quit_app() {
    local pid
    for pid in $(app_pids); do
        kill "$pid" 2> /dev/null || true
        while kill -0 "$pid" 2> /dev/null; do
            sleep 0.5
        done
    done
}

# Preferences are passed as launch arguments, which outrank anything the app has saved,
# so each scene starts from the same place. Saved split view positions are cleared too.
launch_app() {
    local language=$1 locale weather
    shift
    case $language in
        ja) locale=ja_JP ;;
        *) locale=en_US ;;
    esac
    weather=$(print -n '{"name":"Tokyo","latitude":35.6812,"longitude":139.7671}' | xxd -p | tr -d '\n')
    defaults delete "$container_data/Library/Preferences/$bundle_id" 2> /dev/null || true
    mkdir -p "${window_number_file:h}"
    rm -f "$window_number_file"
    open -n "$app_path" --args \
        -ApplePersistenceIgnoreState YES \
        -AppleLanguages "($language)" -AppleLocale "$locale" -AppleInterfaceStyle Dark \
        -Onboarding.Completed YES -App.LaunchCount 100 \
        -App.FetchOnStartup NO -BackgroundRefresh.Enabled NO \
        -Today.Weather.Location "<$weather>" \
        -DebugWindowNumberPath "$window_number_file" \
        "$@"
}

# The first launch creates the database, which the seed then fills.
create_database() {
    [[ -f "$(group_container)/Sakura.feeds" ]] && return 0
    launch_app en
    wait_for_window
    quit_app
}

wait_for_window() {
    local attempts=0
    until [[ -s $window_number_file ]]; do
        attempts=$(( attempts + 1 ))
        (( attempts < 60 )) || { print -u2 "the app never opened its window"; return 1; }
        sleep 0.5
    done
}

# Replaces everything in the database with the sample library from Seed/, in one language.
seed_mac_library() {
    quit_app
    python3 "$assets_dir/Seed/seed.py" --language "$1" --container "$(group_container)" --ids-out "$sample_ids"
}

# Saves the window, shadow included, as `out`, after checking that it came out at exactly
# twice its size in points, which a window on a non-Retina screen or one squeezed to fit
# would not.
capture_window() {
    local out=$1 size=$2 window_number unshadowed=${TMPDIR:-/tmp}/sakura-capture-mac-window.png
    local expected_width=$(( ${size%x*} * 2 )) expected_height=$(( ${size#*x} * 2 )) width height
    window_number=$(< "$window_number_file")
    rm -f "$unshadowed"
    screencapture -x -o -l"$window_number" "$unshadowed" 2> /dev/null || true
    if [[ ! -s $unshadowed ]]; then
        print -u2 "couldn't capture the window; allow Screen Recording for this terminal in System Settings"
        return 1
    fi
    width=$(sips -g pixelWidth "$unshadowed" | awk '/pixelWidth/ { print $2 }')
    height=$(sips -g pixelHeight "$unshadowed" | awk '/pixelHeight/ { print $2 }')
    if [[ $width != "$expected_width" || $height != "$expected_height" ]]; then
        print -u2 "the window came out at ${width}x$height, not ${expected_width}x$expected_height;"
        print -u2 "make sure a Retina display with room for a ${size}pt window is connected"
        return 1
    fi
    mkdir -p "${out:h}"
    screencapture -x -l"$window_number" "$out"
}
