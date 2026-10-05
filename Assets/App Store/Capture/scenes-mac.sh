# The windows captured for the Mac. Sourced, not run.
#
# Window sizes are in points and come out at twice that in pixels. 01-window is drawn
# pixel for pixel on the MacBook's display in Compose/Spreads+Mac.swift, and the four 02
# windows at exactly half, so changing a size here moves it there by the same amount.

settle_seconds=${SETTLE_SECONDS:-8}
main_window_size=1100x690
media_window_size=1100x660

# Draws the content's own thumbnail into a video player that is still black.
fill_mac_player() {
    local capture=$1 poster_file=${TMPDIR:-/tmp}/sakura-capture-poster.jpg
    database "SELECT writefile('$poster_file', data) FROM image_cache
        WHERE url = (SELECT image_url FROM articles WHERE id = $(sample_id "article:$2"))" > /dev/null
    python3 "$assets_dir/Capture/poster.py" "$capture" "$poster_file"
}

# window [--collapse-sidebar] [--select <slug>] [--poster <slug>] <raw name> <size> <location>
window() {
    local -a arguments
    local poster name size location
    while [[ $1 == --* ]]; do
        case $1 in
            --collapse-sidebar) arguments+=(-DebugCollapseSidebar YES); shift ;;
            --select) arguments+=(-DebugSelectContent "$(sample_id "article:$2")"); shift 2 ;;
            --poster) poster=$2; shift 2 ;;
        esac
    done
    name=$1 size=$2 location=$3
    launch_app "$language" "${display_styles[@]}" "${arguments[@]}" \
        -DebugShowLocation "$location" -DebugWindowSize "$size"
    wait_for_window
    sleep "$settle_seconds"
    capture_window "$out_dir/$name.png" "$size"
    if [[ -n $poster ]]; then
        fill_mac_player "$out_dir/$name.png" "$poster"
    fi
    print "captured ${out_dir:t3}/$name.png"
    quit_app
}

capture_mac_scenes() {
    local language=$1 out_dir=$2
    local -a display_styles
    # Only list styles keep the reader beside them, which the video and podcast are shown in.
    display_styles=(
        "-Display.Style.$(sample_id trinity-sweets)" inbox
        "-Display.Style.$(sample_id after-hours)" inbox
        "-Display.Style.$(sample_id r-kivotos)" photos
    )

    window --select schale-open-house 01-window "$main_window_size" "feed:$(sample_id kronos)"
    window --collapse-sidebar --select engineering-railgun \
        02-top-left "$media_window_size" "feed:$(sample_id millennium-times)"
    window --collapse-sidebar --select chestnut-tart --poster chestnut-tart \
        02-top-right "$media_window_size" "feed:$(sample_id trinity-sweets)"
    window --collapse-sidebar --select ep-112 \
        02-bottom-left "$media_window_size" "feed:$(sample_id after-hours)"
    window --collapse-sidebar 02-bottom-right "$media_window_size" "feed:$(sample_id r-kivotos)"
}
