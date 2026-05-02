import SwiftUI

extension OnboardingView {

    var displayStyleStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "newspaper.fill",
                    title: String(localized: "Step.DisplayStyle.Title", table: "Onboarding"),
                    description: String(localized: "Step.DisplayStyle.Description", table: "Onboarding")
                )

                VStack(spacing: 0) {
                    HStack {
                        Text(String(localized: "Setting.DefaultStyle", table: "Onboarding"))
                        Spacer()
                        Picker(String(localized: "Setting.DefaultStyle", table: "Onboarding"), selection: Binding(
                            get: { defaultDisplayStyle },
                            set: { newValue in
                                defaultDisplayStyle = newValue
                                searchDisplayStyle = newValue
                            }
                        )) {
                            Text(String(localized: "Style.Inbox", table: "Articles"))
                                .tag(FeedDisplayStyle.inbox)
                            Text(String(localized: "Style.Compact", table: "Articles"))
                                .tag(FeedDisplayStyle.compact)
                            Text(String(localized: "Style.Feed", table: "Articles"))
                                .tag(FeedDisplayStyle.feed)
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(.regularMaterial, in: .capsule)

                Text(String(localized: "Step.DisplayStyle.Note", table: "Onboarding"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                StylePreviewView(style: defaultDisplayStyle)
                    .allowsHitTesting(false)
                    .padding(.horizontal, -20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            continueButton { advanceStep() }
                .padding(.bottom, isIPad ? 20 : 0)
        }
    }
}

// MARK: - Style Preview

private struct StylePreviewView: View {

    let style: FeedDisplayStyle

    private var sampleArticles: [Article] {
        [
            Article(id: 1, feedID: 1,
                    title: String(localized: "Sample.Title1", table: "Onboarding"),
                    url: "", author: String(localized: "Sample.Author1", table: "Onboarding"),
                    summary: String(localized: "Sample.Summary1", table: "Onboarding"),
                    imageURL: nil, publishedDate: Date().addingTimeInterval(-3600),
                    isRead: false, isBookmarked: false),
            Article(id: 2, feedID: 1,
                    title: String(localized: "Sample.Title2", table: "Onboarding"),
                    url: "", author: String(localized: "Sample.Author2", table: "Onboarding"),
                    summary: String(localized: "Sample.Summary2", table: "Onboarding"),
                    imageURL: nil, publishedDate: Date().addingTimeInterval(-7200),
                    isRead: true, isBookmarked: false),
            Article(id: 3, feedID: 1,
                    title: String(localized: "Sample.Title3", table: "Onboarding"),
                    url: "", author: String(localized: "Sample.Author3", table: "Onboarding"),
                    summary: String(localized: "Sample.Summary3", table: "Onboarding"),
                    imageURL: nil, publishedDate: Date().addingTimeInterval(-10800),
                    isRead: false, isBookmarked: true)
        ]
    }

    var body: some View {
        Group {
            switch style {
            case .inbox:
                inboxPreview
            case .feed:
                feedPreview
            case .magazine, .photos:
                magazinePreview
            case .compact:
                compactPreview
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Inbox Preview

    private var inboxPreview: some View {
        VStack(spacing: 0) {
            ForEach(sampleArticles) { article in
                HStack(alignment: .center, spacing: 8) {
                    Circle()
                        .fill(article.isRead ? .clear : .blue)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.body)
                            .fontWeight(article.isRead ? .regular : .semibold)
                            .lineLimit(1)
                            .foregroundStyle(article.isRead ? .secondary : .primary)
                        if let summary = article.summary {
                            SummaryText(summary: summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if let author = article.author, let date = article.publishedDate {
                            HStack(spacing: 8) {
                                Text(author)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                RelativeTimeText(date: date)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if article.id != sampleArticles.last?.id {
                    Divider()
                        .padding(.leading, 32)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Feed Preview

    private var feedPreview: some View {
        VStack(spacing: 0) {
            ForEach(sampleArticles) { article in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            if let author = article.author {
                                Text(author)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                            }
                            if let date = article.publishedDate {
                                Text("·")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                RelativeTimeText(date: date)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !article.isRead {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        if let summary = article.summary {
                            SummaryText(summary: summary)
                                .font(.subheadline)
                                .lineLimit(3)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if article.id != sampleArticles.last?.id {
                    Divider()
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Magazine Preview

    private var magazinePreview: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(sampleArticles) { article in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.secondary.opacity(0.15))
                        .frame(height: 100)
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(article.isRead ? .regular : .semibold)
                        .lineLimit(2)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                    if let date = article.publishedDate {
                        RelativeTimeText(date: date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: - Compact Preview

    private var compactPreview: some View {
        VStack(spacing: 0) {
            ForEach(sampleArticles) { article in
                HStack {
                    Text(article.title)
                        .font(.caption)
                        .fontWeight(article.isRead ? .regular : .medium)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    if let date = article.publishedDate {
                        RelativeTimeText(date: date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if article.id != sampleArticles.last?.id {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
