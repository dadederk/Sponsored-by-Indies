import Foundation
import Ignite

struct MarketingPage: StaticPage {
    let path: String
    let title: String
    let description: String
    let canonicalPath: String
    let isIndexable: Bool
    let isShowcasePreview: Bool
    let bundleArtwork: BundleArtwork?
    let identity: SiteIdentity
    @Environment(\.site) private var site
    var image: URL? { site.url.appending(path: bundleArtwork?.imagePath ?? ArtworkPaths.brandFile("social-preview", for: identity)) }
    let content: AnyHTML

    init(path: String, title: String, description: String, canonicalPath: String? = nil, isIndexable: Bool = true, isShowcasePreview: Bool = false, bundleArtwork: BundleArtwork? = nil, identity: SiteIdentity = .sponsored, @HTMLBuilder content: () -> some HTML) {
        self.path = path
        self.title = title
        self.description = description
        self.canonicalPath = canonicalPath ?? path
        self.isIndexable = isIndexable
        self.isShowcasePreview = isShowcasePreview
        self.bundleArtwork = bundleArtwork
        self.identity = identity
        self.content = AnyHTML(content())
    }

    var body: some HTML { content }
}
