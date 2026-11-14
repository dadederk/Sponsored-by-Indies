import Foundation
import Ignite

struct IndiesSite: Site {
    let preview: Bool
    let identity: SiteIdentity
    var url: URL
    let homePage: MarketingPage
    private let pages: [MarketingPage]
    private var assetVersion = DesignTokens.version
    var name: String { identity.name }
    var titleSuffix: String { " · " + identity.name }
    var description: String? { identity.summary }
    var useDefaultBootstrapURLs: BootstrapOptions = .localBootstrap
    var builtInIconsEnabled: BootstrapOptions = .localBootstrap
    var darkTheme: (any Theme)? = nil
    var lightTheme: (any Theme)? = IndiesTheme()
    var feedConfiguration: FeedConfiguration? = nil
    var searchIndex: SearchIndex { SearchIndex(pages: [homePage] + pages, siteURL: url) }
    var layout: MarketingLayout { MarketingLayout(preview: preview, identity: identity, searchIndex: searchIndex, assetVersion: assetVersion) }

    init(catalog: Catalog, preview: Bool, url: URL, publicationDate: Date = .now, identity: SiteIdentity = .sponsored) {
        self.preview = preview
        self.identity = identity
        self.url = url
        // Capture the catalogue and date once so rendering and indexing cannot
        // select different editions if a build crosses midnight.
        let registry = Pages(catalog: catalog, date: publicationDate, preview: preview)
        homePage = identity == .sponsored ? registry.home : registry.showcase(preview: preview)
        pages = identity == .sponsored ? registry.all : []
    }

    /// Keep all generated assets and indexing policy inside the staged publication.
    mutating func generate(sourceDirectory: URL, buildDirectory: URL) async throws {
        assetVersion = try AssetFingerprint.make(in: sourceDirectory)
        try await publish(sourceDirectory: sourceDirectory, buildDirectory: buildDirectory)
        try DesignTokens.install(in: buildDirectory)
        try await SocialPreview.install(in: buildDirectory, identity: identity,
                                       bundles: pages.compactMap(\.bundleArtwork))
        try searchIndex.install(in: buildDirectory)
        if !preview && identity == .showcase {
            try ShowcasePublication.install(in: buildDirectory, url: url)
        }
    }

    var staticPages: [any StaticPage] {
        return pages.map { $0 as any StaticPage }
    }
}
