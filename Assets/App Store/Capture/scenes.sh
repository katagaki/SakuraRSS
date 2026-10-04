# The screens captured for each device. Sourced, not run.
#
# Each scene is restored the way the app restores its own tabs on launch: a root location
# (startPage, allContent, feeds, topics, feed:<id>, list:<id>, search:<term>) and, for pages
# pushed above it, the path tokens the app records in its page history.

settle_seconds=${SETTLE_SECONDS:-12}
bookmarks_token='{"bookmarks":{}}'

# The opening of an article's title in the language being captured, to find its row by.
article_title_start() {
    database "$udid" "SELECT substr(title, 1, 16) FROM articles WHERE id = $(sample_id "article:$1")"
}

# Draws the article's own thumbnail, from the image cache, into the black player of a capture.
fill_player() {
    local capture=$1 poster_file=${TMPDIR:-/tmp}/sakura-capture-poster.jpg
    database "$udid" "SELECT writefile('$poster_file', data) FROM image_cache
        WHERE url = (SELECT image_url FROM articles WHERE id = $(sample_id "article:$2"))" > /dev/null
    python3 "$assets_dir/Capture/poster.py" "$capture" "$poster_file"
}

article_token() {
    print "{\"article\":{\"_0\":$(sample_id "article:$1")}}"
}

feed_location() {
    print "feed:$(sample_id "$1")"
}

display_style() {
    write_preference "$udid" "Display.Style.$(sample_id "$1")" -string "$2"
}

tab_id() {
    printf '5A4B0000-0000-4000-8000-%012d' "$1"
}

# Stands an earlier capture in for the snapshot the tab switcher shows on a tab's card.
write_tab_snapshot() {
    local capture=$1 tab=$2 snapshots
    snapshots="$(xcrun simctl get_app_container "$udid" "$bundle_id" data)/Library/Caches/BrowserTabSnapshots"
    mkdir -p "$snapshots"
    python3 "$assets_dir/Capture/snapshot.py" "$capture" "$snapshots/$tab.jpg"
}

# open_tabs <selected index> <tab>...
# Each tab is "<root location>[|<capture for its card>[|<path token JSON>]]".
open_tabs() {
    local selected=$1 index=0 entry root capture token id histories=""
    local -a roots ids
    shift
    for entry in "$@"; do
        root=${entry%%|*}
        capture="" token=""
        [[ $entry == *\|* ]] && capture=${${entry#*|}%%|*}
        [[ ${entry#*|} == *\|* ]] && token=${entry##*|}
        id=$(tab_id $(( index + 1 )))
        roots+=("$root")
        ids+=("$id")
        if [[ -n $token ]]; then
            [[ -n $histories ]] && histories+=","
            histories+="\"$id\":[{\"title\":\"\",\"symbolName\":\"square.grid.2x2\"},"
            histories+="{\"title\":\"\",\"symbolName\":\"doc.text\",\"pathToken\":$token}]"
        fi
        if [[ -n $capture ]]; then
            write_tab_snapshot "$out_dir/$capture.png" "$id"
        fi
        index=$(( index + 1 ))
    done
    write_preference "$udid" Browser.TabTokens -array "${roots[@]}"
    write_preference "$udid" Browser.TabIDs -array "${ids[@]}"
    write_preference "$udid" Browser.SelectedTabIndex -int "$selected"
    if [[ -n $histories ]]; then
        write_preference "$udid" Browser.PageHistories -data "$(print -n "{$histories}" | xxd -p | tr -d '\n')"
    else
        xcrun simctl spawn "$udid" defaults delete "$(app_preferences "$udid")" Browser.PageHistories \
            2>/dev/null || true
    fi
}

# Launches into the restored tabs, optionally taps something, and saves the screen.
capture_scene() {
    local name=$1 tap=$2 wait=$3 poster=$4
    launch_app "$udid"
    sleep "$settle_seconds"
    if [[ -n $tap ]]; then
        tap_label "$udid" "$tap"
        sleep "$wait"
    fi
    mkdir -p "$out_dir"
    xcrun simctl io "$udid" screenshot --type png "$out_dir/$name.png" > /dev/null 2>&1
    if [[ -n $poster ]]; then
        fill_player "$out_dir/$name.png" "$poster"
    fi
    print "captured ${out_dir:t2}/$name.png"
    quit_app "$udid"
}

# scene [--tap <label>] [--wait <seconds>] [--poster <slug>] <raw name> <root location> [<path token JSON>]
# One tab. --tap taps the item whose label contains <label> once the scene has settled, --wait
# is how long to leave it after the tap, and --poster fills the video player, which simulators
# never draw frames into, with that article's thumbnail.
#
# tabs_scene [--tap <label>] [--wait <seconds>] <raw name> <selected index> <tab>...
# Several tabs, as open_tabs takes them.
scene() {
    local tap wait=4 poster tab
    while [[ $1 == --* ]]; do
        case $1 in
            --tap) tap=$2 ;;
            --wait) wait=$2 ;;
            --poster) poster=$2 ;;
        esac
        shift 2
    done
    tab=$2
    [[ -n ${3:-} ]] && tab+="||$3"
    open_tabs 0 "$tab"
    capture_scene "$1" "$tap" "$wait" "$poster"
}

tabs_scene() {
    local tap wait=4 name selected
    while [[ $1 == --* ]]; do
        case $1 in
            --tap) tap=$2 ;;
            --wait) wait=$2 ;;
        esac
        shift 2
    done
    name=$1 selected=$2
    shift 2
    open_tabs "$selected" "$@"
    capture_scene "$name" "$tap" "$wait" ""
}

capture_scenes() {
    local udid=$1 device=$2 language=$3 out_dir=$4
    local tabs_label=Tabs
    [[ $language == ja ]] && tabs_label=タブ

    display_style momoi-midori video
    # Only list styles keep the reader column beside them on iPad, which these two are shown in.
    display_style trinity-sweets inbox
    display_style veritas-hour podcast
    display_style after-hours inbox
    display_style r-kivotos photos
    display_style tech-board cards
    display_style network-status timeline

    case $device in
        iPhone)
            scene 01-today startPage
            scene 01-following allContent
            scene 02-feeds feeds
            scene 03-reader "$(feed_location millennium-times)" "$(article_token engineering-railgun)"
            scene 04-bookmarks startPage "$bookmarks_token"
            scene 05-discover topics
            scene 06-videos "$(feed_location momoi-midori)"
            scene 07-podcasts "$(feed_location veritas-hour)"
            scene 08-visuals "$(feed_location r-kivotos)"
            scene 09-headlines "$(feed_location tech-board)"
            scene 10-incidents "$(feed_location network-status)"
            # The switcher's cards reuse the captures above as the tabs' snapshots.
            tabs_scene --tap "$tabs_label" 99-tabs 1 \
                "startPage|01-today" \
                "$(feed_location millennium-times)|03-reader|$(article_token engineering-railgun)" \
                "$(feed_location r-kivotos)|08-visuals" \
                "$(feed_location tech-board)|09-headlines" \
                "$(feed_location momoi-midori)|06-videos" \
                "$(feed_location network-status)|10-incidents"
            ;;
        iPad)
            # The list stays beside the reader on iPad, so the content is opened from the list.
            scene --tap "$(article_title_start schale-open-house)" 01-reader "$(feed_location kronos)"
            scene --tap "$(article_title_start chestnut-tart)" --wait 10 --poster chestnut-tart 03-videos "$(feed_location trinity-sweets)"
            scene --tap "$(article_title_start ep-112)" 03-podcasts "$(feed_location after-hours)"
            # The tab strip runs along the top on iPad whenever more than one tab is open.
            tabs_scene --tap "$(article_title_start schale-open-house)" 99-tabs 0 \
                "$(feed_location kronos)" \
                "$(feed_location millennium-times)" \
                "$(feed_location trinity-gazette)" \
                "$(feed_location r-kivotos)" \
                "$(feed_location after-hours)"
            print "04-widgets is the Home Screen with widgets, which can't be arranged from a script;"
            print "the capture in Raw/iPad/04-widgets.png is kept."
            ;;
    esac
}
