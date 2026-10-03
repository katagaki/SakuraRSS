# Reddit scrape harness

This isolated iOS app loads a selected subreddit and sort in a `WKWebView`, using `sakuraUserAgent` compiled directly from `Hanami/UserAgent.swift`. The menu includes `r/iOSBeta`, `r/swift`, `r/apple`, and `r/technology`. It extracts rendered `shreddit-post` elements. **More** scrolls the page five times to trigger lazy loading; **Scrape** reads the current DOM; **Headless** runs the production scraper without displaying its web view and verifies stopping at a saved post; **Next** loads a page after the last post; **Reload** starts a fresh page load. The status reports the post count, challenge detection, and whether `navigator.userAgent` equals Sakura's value.

```sh
cd Tools/RedditScrapeHarness
xcodegen generate --spec project.yml
xcodebuild -project RedditScrapeHarness.xcodeproj -scheme RedditScrapeHarness \
  -destination 'platform=iOS Simulator,name=iPhone (iOS 18)' \
  -derivedDataPath /tmp/SakuraRedditHarnessDerived CODE_SIGNING_ALLOWED=NO build
```

Content extraction regression checks use the production snapshot script and browser DOM fixtures:

```sh
node Tools/RedditScrapeHarness/Tests/prepare.mjs /tmp/SakuraRedditContentTests
python3 -m http.server 8765 --directory /tmp/SakuraRedditContentTests
```

Open `http://localhost:8765`; all checks must pass. The fixtures cover focal-post selection, image deduplication,
lazy gallery items, video captions, external links, unsafe URLs, and challenge pages. Validate body formatting,
media rendering, and community icons in Sakura on the simulator as well.
