import Foundation
import Ignite

struct IndiesSite: Site {
    let preview: Bool
    var url: URL
    let homePage: MarketingPage
    private let pages: [MarketingPage]
    private var assetVersion = DesignTokens.version
    var name = "Sponsored by Indies"
    var titleSuffix = " · Sponsored by Indies"
    var description: String? = "Indie apps, games, books, courses, tools… Free products and discounts for attendees of iOS, Swift and Apple platform developer conferences."
    var useDefaultBootstrapURLs: BootstrapOptions = .localBootstrap
    var builtInIconsEnabled: BootstrapOptions = .none
    var darkTheme: (any Theme)? = nil
    var lightTheme: (any Theme)? = IndiesTheme()
    var feedConfiguration: FeedConfiguration? = nil
    var searchIndex: SearchIndex { SearchIndex(pages: [homePage] + pages, siteURL: url) }
    var layout: MarketingLayout { MarketingLayout(preview: preview, searchIndex: searchIndex, assetVersion: assetVersion) }

    init(catalog: Catalog, preview: Bool, url: URL, publicationDate: Date = .now) {
        self.preview = preview
        self.url = url
        // Capture the catalogue and date once so rendering and indexing cannot
        // select different editions if a build crosses midnight.
        let registry = Pages(catalog: catalog, date: publicationDate)
        homePage = registry.home
        pages = registry.all
    }

    /// Keep all generated assets and indexing policy inside the staged publication.
    mutating func generate(sourceDirectory: URL, buildDirectory: URL) async throws {
        assetVersion = try AssetFingerprint.make(in: sourceDirectory)
        try await publish(sourceDirectory: sourceDirectory, buildDirectory: buildDirectory)
        try DesignTokens.install(in: buildDirectory)
        try await SocialPreview.install(in: buildDirectory)
        try searchIndex.install(in: buildDirectory)
    }

    var staticPages: [any StaticPage] {
        return pages.map { $0 as any StaticPage }
    }
}
