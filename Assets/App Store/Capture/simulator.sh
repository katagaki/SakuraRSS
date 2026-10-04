# Simulator lifecycle for capture.sh. Sourced, not run.

bundle_id=com.tsubuzaki.SakuraRSS
app_group=group.com.tsubuzaki.SakuraRSS

step() {
    print -P "%B==> $1%b"
}

# The simulator for a device, created on first use. Prints its UDID.
capture_simulator() {
    local device=$1 name device_type udid runtime
    case $device in
        iPhone)
            name="Sakura Capture iPhone"
            device_type=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro ;;
        iPad)
            name="Sakura Capture iPad"
            device_type=com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-12GB ;;
        *) print -u2 "no simulator for $device"; return 1 ;;
    esac
    udid=$(xcrun simctl list devices -j | python3 -c "
import json, sys
for runtime in json.load(sys.stdin)['devices'].values():
    for device in runtime:
        if device['name'] == sys.argv[1] and device['isAvailable']:
            print(device['udid']); break
" "$name" | head -1)
    if [[ -z $udid ]]; then
        # The newest iOS runtime that can run this device; a fresh runtime can lag behind the device list.
        runtime=$(xcrun simctl list runtimes -j | python3 -c "
import json, sys
runtimes = [runtime for runtime in json.load(sys.stdin)['runtimes']
            if runtime['platform'] == 'iOS' and runtime['isAvailable']
            and any(kind['identifier'] == sys.argv[1] for kind in runtime.get('supportedDeviceTypes', []))]
print(runtimes[-1]['identifier'] if runtimes else '')
" "$device_type")
        [[ -n $runtime ]] || { print -u2 "no runtime supports $device_type"; return 1; }
        udid=$(xcrun simctl create "$name" "$device_type" "$runtime")
    fi
    print $udid
}

# Language and region are system-wide, so the simulator is restarted in them; that also
# puts the status bar's date into the language on iPad.
boot_in_language() {
    local udid=$1 language=$2 locale global_preferences
    case $language in
        ja) locale=ja_JP ;;
        *) locale=en_US ;;
    esac
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    global_preferences=~/Library/Developer/CoreSimulator/Devices/$udid/data/Library/Preferences/.GlobalPreferences.plist
    mkdir -p "${global_preferences:h}"
    [[ -f $global_preferences ]] || plutil -create xml1 "$global_preferences"
    plutil -replace AppleLanguages -json "[\"$language\"]" "$global_preferences"
    plutil -replace AppleLocale -string "$locale" "$global_preferences"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b > /dev/null
    xcrun simctl ui "$udid" appearance dark
    xcrun simctl location "$udid" set 35.6812,139.7671
    xcrun simctl status_bar "$udid" override --time "9:41" \
        --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 \
        --batteryState charged --batteryLevel 100
}

install_app() {
    local udid=$1 app_path=$2
    xcrun simctl install "$udid" "$app_path"
    # The first launch creates the database and the default bookmark folders.
    if [[ -z $(group_container "$udid") || ! -f $(group_container "$udid")/Sakura.feeds ]]; then
        launch_app "$udid"
        sleep 10
        quit_app "$udid"
    fi
}

group_container() {
    xcrun simctl get_app_container "$1" "$bundle_id" groups 2>/dev/null \
        | awk -F'\t' -v group="$app_group" '$1 == group { print $2 }'
}

database() {
    sqlite3 "$(group_container "$1")/Sakura.feeds" "${@:2}"
}

# The app's own defaults live in its data container, not the simulator's shared domain.
app_preferences() {
    print "$(xcrun simctl get_app_container "$1" "$bundle_id" data)/Library/Preferences/$bundle_id"
}

write_preference() {
    local udid=$1
    xcrun simctl spawn "$udid" defaults write "$(app_preferences "$udid")" "${@:2}"
}

launch_app() {
    # A launch that is killed mid-startup otherwise wipes the restored tabs on the next one.
    write_preference "$1" App.StartupInProgress -bool NO
    xcrun simctl launch "$1" "$bundle_id" > /dev/null
}

quit_app() {
    xcrun simctl terminate "$1" "$bundle_id" 2>/dev/null || true
    sleep 1
}

# Turning the simulator and tapping into the app both need a UI test, so they run one from
# the small Driver project. Extra arguments are passed to the test as environment variables.
run_driver_test() {
    local udid=$1 test_name=$2 log=${TMPDIR:-/tmp}/sakura-capture-driver.log
    shift 2
    env "${@/#/TEST_RUNNER_}" xcodebuild test -project "$assets_dir/Capture/Driver/CaptureDriver.xcodeproj" \
        -scheme DriverTests -destination "id=$udid" \
        -derivedDataPath "${TMPDIR:-/tmp}/sakura-capture-driver" \
        -only-testing:"DriverTests/DriverTests/$test_name" > "$log" 2>&1 \
        || { print -u2 "$test_name failed on the simulator, see $log"; return 1; }
}

set_orientation() {
    case $2 in
        landscape) run_driver_test "$1" testLandscape ;;
        *) run_driver_test "$1" testPortrait ;;
    esac
}

# Taps whatever in the app has a label starting with `label`.
tap_label() {
    run_driver_test "$1" testTap CAPTURE_BUNDLE_ID="$bundle_id" CAPTURE_TAP_LABEL="$2"
}
