import Foundation
import Ignite
import Testing

@testable import SponsoredByIndiesWebsite

extension PublishingTests {
    @Test(arguments: [true, false])
    func sponsoredSiteHostsANonIndexableShowcaseWithLocalNavigation(preview: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: CatalogFixture.showcase(), preview: preview,
                              url: try #require(URL(string: "https://sponsored.example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "by-indies-preview/index.html"), encoding: .utf8)
        #expect(html.contains("By Indies preview"))
        #expect(html.contains("By Indies. Home"))
        #expect(!html.contains("brand-sponsored"))
        #expect(html.contains("href=\"/by-indies-preview/\""))
        #expect(html.contains("href=\"/by-indies-preview/#project-tool\""))
        #expect(html.contains("href=\"/conferences/sample/2027/#project-tool\""))
        #expect(html.contains("href=\"/participate/indies/\""))
        #expect(html.contains("href=\"/terms/\""))
        #expect(!html.contains("https://byindies.com/"))
        #expect(!html.contains("http://localhost:8001/"))
        #expect(html.contains("A longer project story &amp; &lt;details&gt;."))
        #expect(html.contains(preview ? "noindex, nofollow" : "noindex, follow"))
        #expect(html.contains("href=\"https://sponsored.example.org/by-indies-preview/\" rel=\"canonical\""))
        let sitemap = try String(contentsOf: root.appending(path: "sitemap.xml"), encoding: .utf8)
        #expect(!sitemap.contains("/by-indies-preview/"))
        let home = try String(contentsOf: root.appending(path: "index.html"), encoding: .utf8)
        #expect(home.contains("brand-sponsored"))
        #expect(home.contains("href=\"" + SiteIdentity.showcase.baseURL(preview: preview) + "/\""))
    }

    @Test(arguments: ["2027-02-01", "2027-02-02", "2027-02-04", "2027-02-05"])
    func showcaseShowsConferenceDatesBeforeDuringAndAfterEdition(day: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: CatalogFixture.showcase(), preview: true,
                              url: try #require(URL(string: SiteIdentity.showcase.previewURL)),
                              publicationDate: try Date(day, strategy: Edition.dayStyle), identity: .showcase)
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "index.html"), encoding: .utf8)
        #expect(html.contains("2–4 February 2027"))
        for label in ["Upcoming conference", "Current conference", "Past conference"] {
            #expect(!html.contains(label))
        }
    }

    @Test(arguments: [true, false])
    func showcasePublishesProjectsBuildersAndDirectBundleLinks(preview: Bool) async throws {
        var catalog = CatalogFixture.showcase()
        catalog.indies[0].people = [
            IndiePerson(name: "One & <Builder>", websiteURL: "https://example.org/one?x=1&y=2", bio: "Makes useful & <thoughtful> things.", portraitPath: "/portraits/dani-devesa.jpg", creditName: "Short credit"),
            IndiePerson(name: "Two Builder", websiteURL: nil, socials: [SocialLink(label: "Social & <more>", url: "https://example.org/social")])
        ]
        catalog.discoveryResources = [DiscoveryResource(name: "More & <indies>", url: "https://example.org/discover", description: "A little & <discovery>.")]
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let date = try Date("2028-01-01", strategy: Edition.dayStyle)
        var site = IndiesSite(catalog: catalog, preview: preview, url: try #require(URL(string: SiteIdentity.showcase.baseURL(preview: preview))), publicationDate: date, identity: .showcase)
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "index.html"), encoding: .utf8)
        #expect(html.contains("By Indies. Home"))
        #expect(!html.contains("brand-sponsored"))
        #expect(html.contains("One &amp; &lt;Builder&gt;"))
        #expect(!html.contains("Short credit"))
        #expect(html.contains("Makes useful &amp; &lt;thoughtful&gt; things."))
        #expect(html.contains("A longer project story &amp; &lt;details&gt;."))
        #expect(html.contains("/portraits/dani-devesa.jpg"))
        #expect(html.contains("builder-initials"))
        #expect(html.contains("Meet the builders"))
        #expect(!html.contains("Sample Company"))
        #expect(html.contains("Website<span class=\"visually-hidden\"> for One &amp; &lt;Builder&gt;</span>"))
        #expect(html.contains("Social &amp; &lt;more&gt;<span class=\"visually-hidden\"> for Two Builder</span>"))
        #expect(html.contains("2–4 February 2027"))
        #expect(html.contains("href=\"/#project-tool\""))
        #expect(html.contains("Copy link to Tool &amp; &lt;Kit&gt;"))
        #expect(html.contains("aria-label=\"Link to Tool &amp; <Kit>\""))
        #expect(html.contains("data-offer-copy-status"))
        #expect(html.contains("offer-sharing.mjs?v="))
        #expect(html.contains("More &amp; &lt;indies&gt;"))
        #expect(html.contains("https://example.org/one?x=1&amp;y=2"))
        #expect(!html.contains("product-card-benefits"))
        #expect(!html.contains("offer-terms.mjs"))
        #expect(!html.contains("Free access."))
        let sponsored = SiteIdentity.sponsored.baseURL(preview: preview)
        for path in ["/", "/participate/indies/", "/terms/", "/conferences/sample/2027/#project-tool"] {
            #expect(html.contains("href=\"" + sponsored + path + "\""))
        }
        #expect(html.contains("<link href=\"" + SiteIdentity.showcase.baseURL(preview: preview) + "/\" rel=\"canonical\""))
        let sitemap = try String(contentsOf: root.appending(path: "sitemap.xml"), encoding: .utf8)
        #expect(sitemap.contains(SiteIdentity.showcase.baseURL(preview: preview) + "/"))
        #expect(!sitemap.contains("/conferences/"))
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: "conferences").path))
    }
}
