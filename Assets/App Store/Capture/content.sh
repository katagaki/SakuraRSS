# The sample library for capture.sh. Sourced, not run.

sample_ids=${TMPDIR:-/tmp}/sakura-capture-ids.tsv

# Replaces everything in the database with the sample library from Seed/, in one language.
seed_library() {
    local udid=$1 language=$2
    quit_app "$udid"
    python3 "$assets_dir/Seed/seed.py" --language "$language" \
        --container "$(group_container "$udid")" --ids-out "$sample_ids"
    write_preference "$udid" Onboarding.Completed -bool YES
    # Past the launch that asks for a review.
    write_preference "$udid" App.LaunchCount -int 100
    # The sample feeds have nowhere to be fetched from.
    write_preference "$udid" App.FetchOnStartup -bool NO
    write_preference "$udid" BackgroundRefresh.Enabled -bool NO
    # A fixed place keeps the weather from asking for location access.
    write_preference "$udid" Today.Weather.Location -data \
        "$(print -n '{"name":"Tokyo","latitude":35.6812,"longitude":139.7671}' | xxd -p | tr -d '\n')"
}

# The database ID of a feed (by its key in Seed/Feeds) or an article (article:<slug>).
sample_id() {
    awk -F'\t' -v key="$1" '$1 == key { print $2 }' "$sample_ids"
}

# Keeps a copy of the freshly seeded library in Databases/<language>/, before the app touches it.
save_library() {
    local udid=$1 language=$2 container out_dir=$assets_dir/Databases/$2
    container=$(group_container "$udid")
    rm -rf "$out_dir"
    mkdir -p "$out_dir"
    sqlite3 "$container/Sakura.feeds" "VACUUM INTO '$out_dir/Sakura.feeds'"
    mkdir -p "$out_dir/FaviconCache"
    cp "$container"/FaviconCache/custom-feed-*.png "$out_dir/FaviconCache/"
    cp "$sample_ids" "$out_dir/ids.tsv"
}
