import Foundation
import Ignite

struct MarketingLayout: Layout {
    let preview: Bool
    var identity: SiteIdentity = .sponsored
    var searchIndex: SearchIndex? = nil
    var assetVersion: String = DesignTokens.version
    @Environment(\.page) private var page
    @Environment(\.site) private var site

    private var canonicalURL: URL { searchIndex?.canonicalURL(for: page.url) ?? page.url }
    private var hostedShowcase: Bool { searchIndex?.isShowcasePreview(page.url) == true }
    private var pageIdentity: SiteIdentity { hostedShowcase ? .showcase : identity }
    private var homePath: String { hostedShowcase ? SiteIdentity.showcasePreviewPath : "/" }

    var body: some Document {
        Head {
            // Ignite cannot override its automatic canonical/og:url. Use
            // its custom-head API so each appears exactly once with our policy.
            MetaTag.utf8
            MetaTag.flexibleViewport
            MetaTag.generator
            Title(page.title)
            MetaTag(name: "description", content: escaped(page.description))
            MetaLink.standardCSS
            MetaLink.iconCSS
            MetaLink(href: "/css/ignite-core.min.css?v=\(assetVersion)", rel: "stylesheet")
            MetaLink(href: canonicalURL, rel: "canonical")
            MetaTag(.openGraphSiteName, content: escaped(pageIdentity.name))
            MetaTag(.openGraphTitle, content: escaped(page.title))
            MetaTag(.twitterTitle, content: escaped(page.title))
            MetaTag(.openGraphDescription, content: escaped(page.description))
            MetaTag(.twitterDescription, content: escaped(page.description))
            MetaTag(.openGraphURL, content: canonicalURL)
            MetaTag(.twitterDomain, content: site.url.host() ?? "")
            MetaTag(.twitterCard, content: "summary_large_image")
            MetaTag(.twitterDoNotTrack, content: "on")
            if let image = page.image {
                MetaTag(.openGraphImage, content: image.appending(queryItems: [URLQueryItem(name: "v", value: assetVersion)]))
                MetaTag(.twitterImage, content: image.appending(queryItems: [URLQueryItem(name: "v", value: assetVersion)]))
                MetaTag(property: "og:image:width", content: "1200")
                MetaTag(property: "og:image:height", content: "630")
                MetaTag(property: "og:image:type", content: "image/png")
                MetaTag(property: "og:image:alt", content: escaped(searchIndex?.imageDescription(for: page.url) ?? identity.imageDescription))
                MetaTag(name: "twitter:image:alt", content: escaped(searchIndex?.imageDescription(for: page.url) ?? identity.imageDescription))
            }
            MetaLink(href: "/design-tokens.css?v=\(assetVersion)", rel: "stylesheet")
            MetaLink(href: "/styles.css?v=tokens-\(assetVersion)", rel: "stylesheet")
            MetaTag(name: "theme-color", content: DesignTokens.palette.ink)
            MetaLink(href: "/favicon.ico?v=\(assetVersion)", rel: "icon")
                .customAttribute(name: "sizes", value: "32x32")
            MetaLink(href: "/apple-touch-icon.png?v=\(assetVersion)", rel: "apple-touch-icon")
                .customAttribute(name: "sizes", value: "180x180")
            MetaLink(href: "/favicon-shared-imprint-01.svg?v=\(assetVersion)", rel: "icon")
                .customAttribute(name: "type", value: "image/svg+xml")
                .customAttribute(name: "sizes", value: "any")
            if preview {
                MetaTag(name: "robots", content: "noindex, nofollow")
            } else if searchIndex?.isIndexable(page.url) == false {
                MetaTag(name: "robots", content: "noindex, follow")
            }
        }
        .standardHeadersDisabled()
        Body {
            Components.header(assetVersion: assetVersion, identity: pageIdentity, preview: preview,
                              homePath: homePath, sponsoredRoot: hostedShowcase ? "" : nil)
            Tag("main") { content }.id("main").attribute("tabindex", "-1")
            Components.footer(assetVersion: assetVersion, identity: pageIdentity, preview: preview,
                              homePath: homePath, sponsoredRoot: hostedShowcase ? "" : nil)
        }
        .ignorePageGutters()
    }
}
