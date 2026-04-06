import SwiftUI
import WebKit
import FoundationModels
@preconcurrency import Translation

struct YouTubePlayerView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    let article: Article

    @State private var isBookmarked = false
    @State private var isPlaying = false
    @State private var isPiPEligible = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var webView: WKWebView?
    @State private var isAd = false
    @State private var advertiserURL: URL?
    @State private var hasStartedPlaying = false
    @State private var isPiP = false
    @State private var videoAspectRatio: CGFloat = 16 / 9
    @State private var feed: Feed?
    @State private var favicon: UIImage?
    @State private var acronymIcon: UIImage?

    // SponsorBlock
    @AppStorage("YouTube.SponsorBlock.Enabled") private var sponsorBlockEnabled = false
    @AppStorage("YouTube.SponsorBlock.Categories") private var sponsorBlockCategories = "sponsor,selfpromo,interaction"
    @State private var sponsorSegments: [SponsorSegment] = []
    @State private var skippedSegmentIDs: Set<String> = []
    @State private var skippedSegmentMessage: String?

    // Translation & summarization
    @State private var translatedText: String?
    @State private var translatedSummary: String?
    @State private var isTranslating = false
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var showingTranslation = false
    @State private var hasCachedTranslation = false
    @State private var summarizedText: String?
    @State private var isSummarizing = false
    @State private var hasCachedSummary = false
    @State private var showingSummary = false
    @State private var summarizationError: String?

    private var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    private var descriptionSource: String? {
        article.summary ?? article.content
    }

    private var hasDescription: Bool {
        guard let descriptionSource else { return false }
        return !descriptionSource.isEmpty
    }

    private var hasTranslationForCurrentMode: Bool {
        if showingSummary {
            return translatedSummary != nil
        }
        return translatedText != nil || hasCachedTranslation
    }

    private var displayDescription: String? {
        if showingSummary, let summarizedText {
            if showingTranslation, let translatedSummary {
                return translatedSummary
            }
            return summarizedText
        }
        if showingTranslation, let translatedText {
            return translatedText
        }
        return descriptionSource
    }

    private var youtubeAppURL: URL? {
        guard let url = URL(string: article.url),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "youtube"
        return components.url
    }

    @ViewBuilder
    private var feedAvatarView: some View {
        if let favicon {
            FaviconImage(favicon, size: 36, circle: true, skipInset: true)
        } else if let acronymIcon {
            FaviconImage(acronymIcon, size: 36, circle: true, skipInset: true)
        } else if let feed {
            InitialsAvatarView(feed.title, size: 36, circle: true)
        } else {
            Circle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 36, height: 36)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            YouTubePlayerWebView(
                urlString: article.url,
                isPlaying: $isPlaying,
                currentTime: $currentTime,
                duration: $duration,
                webView: $webView,
                isAd: $isAd,
                advertiserURL: $advertiserURL,
                videoAspectRatio: $videoAspectRatio,
                isPiP: $isPiP
            )
            .aspectRatio(videoAspectRatio, contentMode: .fit)
            .clipped()
            .overlay(alignment: .top) {
                if let skippedSegmentMessage {
                    Text(skippedSegmentMessage)
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.smooth.speed(2.0), value: skippedSegmentMessage)
            .overlay {
                if isPiP {
                    Color.black
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "pip.fill")
                                    .font(.largeTitle)
                                Text(String(localized: "YouTube.PiP.Active"))
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }
                } else if !hasStartedPlaying {
                    Color.black
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }

            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    // Title
                    WordWrappingText(article.title, font: .preferredFont(forTextStyle: .title2, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    // Seek bar
                    SeekBarView(
                        currentTime: Binding(
                            get: { currentTime },
                            set: { currentTime = $0 }
                        ),
                        duration: duration,
                        isDisabled: isAd,
                        segments: sponsorSegments.map { (start: $0.startTime, end: $0.endTime) },
                        onSeek: { seek(to: $0) }
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // Playback controls
                    HStack(spacing: 32) {
                        Button {
                            togglePiP()
                        } label: {
                            Image(systemName: "pip.enter")
                                .font(.title2)
                        }

                        Button {
                            rewind()
                        } label: {
                            Image(systemName: "gobackward.10")
                                .font(.title2)
                        }
                        .disabled(isAd)

                        Button {
                            togglePlayPause()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                        }

                        Button {
                            fastForward()
                        } label: {
                            Image(systemName: "goforward.10")
                                .font(.title2)
                        }
                        .disabled(isAd)

                        Button {
                            enterFullscreen()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.top, 16)

                    // Visit Advertiser button
                    if isAd, let advertiserURL {
                        Button {
                            openURL(advertiserURL)
                        } label: {
                            Text(String(localized: "YouTube.VisitAdvertiser"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    // Channel info
                    if let feed {
                        HStack(alignment: .top, spacing: 12) {
                            feedAvatarView

                            VStack(alignment: .leading, spacing: 2) {
                                Text(feed.title)
                                    .font(.subheadline.bold())
                                if let date = article.publishedDate {
                                    RelativeTimeText(date: date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }

                    // Action buttons
                    descriptionActionButtons

                    // Description
                    if let text = displayDescription, !text.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            if showingSummary && summarizedText != nil {
                                Text("AppleIntelligence.VerifyImportantInformation")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            let blocks = ContentBlock.parse(text)
                            ForEach(blocks) { block in
                                switch block {
                                case .text(let content):
                                    SelectableText(content)
                                case .code(let content):
                                    CodeBlockView(code: content)
                                case .image(let url, _):
                                    CachedAsyncImage(url: url) {
                                        Rectangle()
                                            .fill(.secondary.opacity(0.1))
                                            .frame(height: 200)
                                    }
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .id("\(showingSummary)-\(showingTranslation)")
                            .transition(.blurReplace)
                        }
                        .animation(.smooth.speed(2.0), value: showingSummary)
                        .animation(.smooth.speed(2.0), value: showingTranslation)
                        .animation(.smooth.speed(2.0), value: translatedText)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    Spacer()
                        .frame(height: 32)
                }
            }
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isBookmarked.toggle()
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let shareURL = URL(string: article.url) {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Article.Share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isLandscape {
                enterFullscreen()
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue && !hasStartedPlaying {
                withAnimation(.smooth.speed(2.0)) {
                    hasStartedPlaying = true
                }
            }
        }
        .onChange(of: isAd) { _, newValue in
            webView?.isUserInteractionEnabled = newValue
        }
        .onChange(of: currentTime) { _, newTime in
            checkSponsorSegments(at: newTime)
        }
        .task {
            isBookmarked = article.isBookmarked
            let signedIn = await YouTubePlayerView.hasYouTubeSession()
            let premium = signedIn ? await YouTubePlayerView.hasYouTubePremium() : false
            isPiPEligible = signedIn && premium

            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
            }

            if sponsorBlockEnabled,
               let videoID = SponsorBlockClient.extractVideoID(from: article.url) {
                let categories = sponsorBlockCategories
                    .split(separator: ",")
                    .map(String.init)
                sponsorSegments = await SponsorBlockClient.fetchSegments(
                    for: videoID, categories: categories
                )
            }

            if let cached = try? DatabaseManager.shared.cachedArticleTranslation(for: article.id) {
                if cached.text != nil { hasCachedTranslation = true }
                translatedText = cached.text
            }
            if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
               !cached.isEmpty {
                hasCachedSummary = true
            }
        }
        .alert(String(localized: "Article.Summarize.Error"), isPresented: Binding(
            get: { summarizationError != nil },
            set: { if !$0 { summarizationError = nil } }
        )) {
        } message: {
            if let summarizationError {
                Text(summarizationError)
            }
        }
        .translationTask(translationConfig) { session in
            await handleTranslation(session: session)
        }
    }

}

// MARK: - Description Actions

extension YouTubePlayerView {

    private var descriptionActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if hasDescription {
                    translationButton
                    if isAppleIntelligenceAvailable {
                        summarizationButton
                    }
                }
                if let youtubeAppURL, UIApplication.shared.canOpenURL(youtubeAppURL) {
                    Button {
                        UIApplication.shared.open(youtubeAppURL)
                    } label: {
                        Label(
                            String(localized: "YouTube.OpenInApp"),
                            systemImage: "play.rectangle"
                        )
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                }
                Button {
                    if let url = URL(string: article.url) {
                        openURL(url)
                    }
                } label: {
                    Label(
                        String(localized: "YouTube.OpenInBrowser"),
                        systemImage: "safari"
                    )
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .padding(.horizontal)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var translationButton: some View {
        if hasTranslationForCurrentMode && !isTranslating {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingTranslation.toggle()
                }
            } label: {
                Label(
                    String(localized: showingTranslation
                           ? "Article.ShowOriginal"
                           : "Article.ShowTranslation"),
                    systemImage: showingTranslation
                        ? "doc.plaintext" : "translate"
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        } else {
            Button {
                triggerTranslation()
            } label: {
                Label(
                    String(localized: "Article.Translate"),
                    systemImage: "translate"
                )
                .opacity(isTranslating ? 0 : 1)
                .overlay {
                    if isTranslating {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .disabled(isTranslating)
            .animation(.smooth.speed(2.0), value: isTranslating)
        }
    }

    @ViewBuilder
    private var summarizationButton: some View {
        if (summarizedText != nil || hasCachedSummary) && !isSummarizing {
            Button {
                if summarizedText == nil {
                    Task {
                        await summarizeDescription()
                        if summarizedText != nil {
                            withAnimation(.smooth.speed(2.0)) {
                                showingSummary = true
                            }
                        }
                    }
                } else {
                    withAnimation(.smooth.speed(2.0)) {
                        showingSummary.toggle()
                    }
                }
            } label: {
                Label(
                    String(localized: showingSummary
                           ? "Article.ShowOriginal"
                           : "Article.ShowSummary"),
                    systemImage: showingSummary
                        ? "doc.plaintext" : "apple.intelligence"
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        } else {
            Button {
                Task {
                    await summarizeDescription()
                    if summarizedText != nil {
                        withAnimation(.smooth.speed(2.0)) {
                            showingSummary = true
                        }
                    }
                }
            } label: {
                Label(
                    String(localized: "Article.Summarize"),
                    systemImage: "apple.intelligence"
                )
                .opacity(isSummarizing ? 0 : 1)
                .overlay {
                    if isSummarizing {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .disabled(isSummarizing)
            .animation(.smooth.speed(2.0), value: isSummarizing)
        }
    }
}

// MARK: - Translation & Summarization

extension YouTubePlayerView {

    func triggerTranslation() {
        if translationConfig == nil {
            translationConfig = .init()
        } else {
            translationConfig?.invalidate()
        }
    }

    func handleTranslation(session: TranslationSession) async {
        isTranslating = true
        defer { isTranslating = false }

        if showingSummary, let summarizedText {
            guard !summarizedText.isEmpty else { return }
            do {
                let response = try await session.translate(summarizedText)
                translatedSummary = response.targetText
                showingTranslation = true
                try? DatabaseManager.shared.cacheTranslatedSummary(
                    response.targetText, for: article.id
                )
            } catch {
                // Translation failed; user can retry
            }
        } else {
            let source = ContentBlock.plainText(from: descriptionSource ?? "")
            guard !source.isEmpty else { return }
            do {
                let response = try await session.translate(source)
                translatedText = response.targetText
                hasCachedTranslation = true
                showingTranslation = true
                try? DatabaseManager.shared.cacheArticleTranslation(
                    title: nil, text: response.targetText, for: article.id
                )
            } catch {
                // Translation failed; user can retry
            }
        }
    }

    func summarizeDescription() async {
        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            summarizedText = cached
            return
        }

        let source = ContentBlock.plainText(from: descriptionSource ?? "")
        guard !source.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        let instructions = String(localized: "Article.Summarize.Prompt")

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: source)
            summarizedText = response.content
            try? DatabaseManager.shared.cacheArticleSummary(response.content, for: article.id)
        } catch {
            summarizationError = error.localizedDescription
        }
    }
}

// MARK: - SponsorBlock

extension YouTubePlayerView {

    func checkSponsorSegments(at time: TimeInterval) {
        guard sponsorBlockEnabled, !isAd, !sponsorSegments.isEmpty else { return }
        for segment in sponsorSegments {
            if time >= segment.startTime && time < segment.endTime
                && !skippedSegmentIDs.contains(segment.id) {
                skippedSegmentIDs.insert(segment.id)
                seek(to: segment.endTime + 0.1)
                let categoryName = SponsorBlockCategory(rawValue: segment.category)?
                    .displayName ?? segment.category
                skippedSegmentMessage = String(
                    localized: "YouTube.SponsorBlock.Skipped \(categoryName)"
                )
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        skippedSegmentMessage = nil
                    }
                }
                return
            }
        }
    }
}

// MARK: - Playback Controls

extension YouTubePlayerView {

    func togglePlayPause() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) {
                if (video.paused) { video.play(); } else { video.pause(); }
                return !video.paused;
            }
            return null;
        })();
        """
        webView?.evaluateJavaScript(script) { result, _ in
            if let playing = result as? Bool {
                isPlaying = playing
            }
        }
    }

    func seek(to time: TimeInterval) {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime = \(time); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func rewind() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime = Math.max(0, video.currentTime - 10); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func fastForward() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime += 10; }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func enterFullscreen() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video && video.webkitEnterFullscreen) {
                video.webkitEnterFullscreen();
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func togglePiP() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) {
                if (document.pictureInPictureElement) {
                    document.exitPictureInPicture();
                } else if (video.requestPictureInPicture) {
                    video.requestPictureInPicture();
                }
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}

// MARK: - Session

extension YouTubePlayerView {

    private static let youtubeSessionCacheKey = "YouTubePlayerView.hasSession"

    @MainActor
    static func hasYouTubeSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        let found = cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("youtube.com") || domain.contains("google.com"))
                && (cookie.name == "SID" || cookie.name == "SSID" || cookie.name == "LOGIN_INFO")
        }

        if found {
            UserDefaults.standard.set(true, forKey: youtubeSessionCacheKey)
            return true
        }

        // Retry once after a delay to let WebKit finish loading cookies from disk.
        if UserDefaults.standard.bool(forKey: youtubeSessionCacheKey) {
            try? await Task.sleep(for: .milliseconds(500))
            let retryResult = await retryHasYouTubeSession()
            UserDefaults.standard.set(retryResult, forKey: youtubeSessionCacheKey)
            return retryResult
        }

        UserDefaults.standard.set(false, forKey: youtubeSessionCacheKey)
        return false
    }

    @MainActor
    private static func retryHasYouTubeSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("youtube.com") || domain.contains("google.com"))
                && (cookie.name == "SID" || cookie.name == "SSID" || cookie.name == "LOGIN_INFO")
        }
    }

    static func hasYouTubePremium() async -> Bool {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        // swiftlint:disable line_length
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        // swiftlint:enable line_length

        return await withCheckedContinuation { continuation in
            let delegate = PremiumCheckDelegate { isPremium in
                continuation.resume(returning: isPremium)
            }
            webView.navigationDelegate = delegate
            objc_setAssociatedObject(webView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.load(URLRequest(url: URL(string: "https://m.youtube.com/")!))
        }
    }

    @MainActor
    static func clearYouTubeSession() async {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("youtube.com")
            || cookie.domain.lowercased().contains("google.com")
            || cookie.domain.lowercased().contains("accounts.google.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
        UserDefaults.standard.set(false, forKey: youtubeSessionCacheKey)
    }
}
