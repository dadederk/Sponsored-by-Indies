import Foundation
import Ignite
import Testing

@testable import SponsoredByIndiesWebsite

extension PublishingTests {
    @Test(arguments: [true, false])
    func makerDisclosuresAreOptionalAndEscapedOnBothSites(hasDisclosure: Bool) async throws {
        var catalog = CatalogFixture.showcase()
        let disclosure = "Maker & <coordinator>."
        catalog.indies[0].disclosure = hasDisclosure ? disclosure : nil
        try catalog.validate()
        for identity in [SiteIdentity.sponsored, .showcase] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            var site = IndiesSite(catalog: catalog, preview: true,
                                  url: try #require(URL(string: "https://example.org")), identity: identity)
            try await site.generate(sourceDirectory: source, buildDirectory: root)
            let routes = identity == .sponsored
                ? ["conferences/sample/2027/index.html", "by-indies-preview/index.html"] : ["index.html"]
            for route in routes {
                let html = try String(contentsOf: root.appending(path: route), encoding: .utf8)
                #expect(html.components(separatedBy: escaped(disclosure)).count == (hasDisclosure ? 2 : 1))
                #expect(!html.contains(disclosure))
            }
        }
    }

    @Test func bundlesShareTheirOwnArtworkAcrossEditionHubAndAccessPages() async throws {
        let catalog = CatalogFixture.make()
        let artwork = BundleArtwork(conference: catalog.conferences[0], edition: catalog.editions[0])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let origin = try #require(URL(string: "https://example.org"))
        var site = IndiesSite(catalog: catalog, preview: true, url: origin)
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let image = try Data(contentsOf: root.appending(path: String(artwork.imagePath.dropFirst())))
        #expect(Array(image.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
        for route in ["conferences/sample/", "conferences/sample/2027/", "conferences/sample/2027/access/"] {
            let html = try String(contentsOf: root.appending(path: route + "index.html"), encoding: .utf8)
            let prefix = "https://example.org" + artwork.imagePath + "?v="
            #expect(html.contains("property=\"og:image\" content=\"" + prefix))
            #expect(html.contains("name=\"twitter:image\" content=\"" + prefix))
            #expect(html.contains("content=\"" + artwork.imageDescription + "\""))
        }
        var renamed = artwork.conference
        renamed.name += " & Friends"
        #expect(BundleArtwork(conference: renamed, edition: artwork.edition).imagePath != artwork.imagePath)
        var rescheduled = artwork.edition
        rescheduled.dateLabel = "9–11 February 2027"
        #expect(BundleArtwork(conference: artwork.conference, edition: rescheduled).imagePath != artwork.imagePath)
        var rebranded = artwork.conference
        rebranded.branding?.accent = "#ffffff"
        #expect(BundleArtwork(conference: rebranded, edition: artwork.edition).imagePath != artwork.imagePath)
    }

    @Test func confirmedPricesPublishInDialogFallbackAndBundleCalculation() async throws {
        var catalog = CatalogFixture.make()
        var evidence = CatalogFixture.saving(price: Decimal(string: "69.99")!, percent: 30)
        evidence.confirmedOfferPriceUSD = Decimal(string: "48.99")!
        catalog.offers[0].savingEstimate = evidence
        catalog.offers[0].benefit = "30% off your first year"
        catalog.editions[0].valueSummary = ValueSummary(explanation: "Compatible offers.", offerIDs: [catalog.offers[0].id])
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "conferences/sample/2027/index.html"), encoding: .utf8)
        let card = try #require(html.firstMatch(of: /<article\b[^>]*class="panel product-card"[^>]*>[\s\S]*?<\/article>/))
        let text = String(card.output)
        let fallback = try #require(text.firstMatch(of: /<details[\s\S]*?<\/details>/))
        let dialog = text.components(separatedBy: String(fallback.output))[0]
        for terms in [dialog, String(fallback.output)] {
            #expect(terms.contains("US$48.99 for the first year"))
            #expect(terms.contains("Save US$21.00 (30%)."))
            #expect(!terms.contains("US$49.00"))
        }
        #expect(html.contains("up to US$21"))
        #expect(html.contains("US$69.99 − US$48.99 maker-confirmed offer price = US$21.00"))
    }

    @Test func offerPermalinksStayWithTheirEditionAndGroupAlternativeOffers() async throws {
        var catalog = CatalogFixture.showcase()
        var alternative = catalog.offers[0]
        alternative.id = "alternative"
        alternative.benefit = "Another option"
        catalog.offers.append(alternative)
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        for path in ["conferences/sample/index.html", "conferences/sample/2027/index.html"] {
            let html = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(html.contains("id=\"project-tool\""))
            #expect(html.contains("href=\"/conferences/sample/2027/#project-tool\""))
            #expect(html.matches(of: /data-offer-sharing="true"/).count == 1)
            #expect(html.contains("Link to this offer"))
            #expect(html.contains("/offer-sharing.mjs"))
        }
    }

    @Test func makerCreditsLinkEachPersonSeparatelyFromTheCompany() async throws {
        var catalog = CatalogFixture.make()
        catalog.indies[0].people = [
            IndiePerson(name: "Hidde & <Friends>", websiteURL: "https://example.org/hidde?event=one&copy;=yes"),
            IndiePerson(name: "Pol Piella", websiteURL: "https://example.org/pol", creditName: "Pol")
        ]
        catalog.participations[0].quoteAttribution = QuoteAttribution(name: "Pol & <Team>", sourceURL: "https://example.org/quote?issue=81&copy;=yes")
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "conferences/sample/2027/index.html"), encoding: .utf8)
        let card = try #require(html.firstMatch(of: /<article\b[^>]*class="panel product-card"[^>]*>[\s\S]*?<\/article>/))
        let text = String(card.output)
        #expect(text.contains("href=\"https://example.org/hidde?event=one&amp;copy;=yes\""))
        #expect(text.contains(">Hidde &amp; &lt;Friends&gt;</a>"))
        #expect(text.range(of: #"<a[^>]*href="https://example.org/pol"[^>]*>Pol</a>"#, options: .regularExpression) != nil)
        #expect(!text.contains("Pol Piella"))
        #expect(text.contains("href=\"https://example.org/maker\""))
        #expect(text.contains("Sample Company"))
        #expect(!text.contains("<Friends>"))
        let quote = try #require(text.firstMatch(of: /<blockquote[\s\S]*?<\/blockquote>/))
        #expect(!String(quote.output).contains("<a"))
        #expect(String(quote.output).contains(" – Pol &amp; &lt;Team&gt;"))
        #expect(!String(quote.output).contains("<Team>"))
    }

    @Test(arguments: [true, false])
    func aSoleMakersQuoteDoesNotRepeatTheirName(explicitProfile: Bool) async throws {
        var catalog = CatalogFixture.make()
        if explicitProfile {
            catalog.indies[0].people = [IndiePerson(name: "Sole maker", websiteURL: "https://example.org/profile")]
        }
        catalog.participations[0].quoteAttribution = QuoteAttribution(name: "Sole maker", sourceURL: "https://example.org/quote")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "conferences/sample/2027/index.html"), encoding: .utf8)
        let quote = try #require(html.firstMatch(of: /<blockquote[\s\S]*?<\/blockquote>/))
        #expect(String(quote.output).contains("A welcoming community."))
        #expect(!String(quote.output).contains("Sole maker"))
        #expect(!String(quote.output).contains("<a"))
        #expect(html.contains(explicitProfile ? "href=\"https://example.org/profile\"" : "href=\"https://example.org/maker\""))
    }

    @Test(arguments: [true, false])
    func groupedOffersKeepTheirRedemptionInstructions(shared: Bool) async throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].benefit = "Lifetime discount"
        catalog.offers[0].redemptionInstructions = "Open the lifetime & member portal."
        var alternative = catalog.offers[0]
        alternative.id = "tool-yearly"
        alternative.benefit = "Free year"
        if !shared { alternative.redemptionInstructions = "Claim the yearly licence." }
        catalog.offers.append(alternative)
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "conferences/sample/2027/index.html"), encoding: .utf8)
        let card = try #require(html.firstMatch(of: /<article\b[^>]*class="panel product-card"[^>]*>[\s\S]*?<\/article>/))
        let instructions = "Open the lifetime &amp; member portal."
        let fallback = try #require(String(card.output).firstMatch(of: /<details[\s\S]*?<\/details>/))
        let dialog = String(card.output).components(separatedBy: String(fallback.output))[0]
        #expect(dialog.contains("Choose one offer:"))
        #expect(String(fallback.output).contains("Choose one offer:"))
        let options = try #require(dialog.firstMatch(of: /<ul[^>]*aria-label="Offer options"[^>]*>[\s\S]*?<\/ul>/))
        let items = String(options.output).matches(of: /<li[^>]*>[\s\S]*?<\/li>/).map { String($0.output) }
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.contains("Estimated price:") && $0.contains("Regular US price:") && $0.contains("Save US$10.00 (100%).") })
        #expect(dialog.components(separatedBy: instructions).count == 2)
        #expect(String(fallback.output).components(separatedBy: instructions).count == 2)
        if !shared {
            let lifetime = try #require(items.first { $0.contains("Lifetime discount") })
            let yearly = try #require(items.first { $0.contains("Free year") })
            #expect(lifetime.contains(instructions))
            #expect(!lifetime.contains("Claim the yearly licence."))
            #expect(yearly.contains("Claim the yearly licence."))
            #expect(!yearly.contains(instructions))
        }
    }

    @Test(arguments: ["approved", "unapproved", "empty", "archived"])
    func attendeeThanksFollowsVisibleEditionOffers(state: String) async throws {
        var catalog = CatalogFixture.make()
        if state == "unapproved" { catalog.offers[0].publicationApproved = false }
        if state == "empty" { catalog.offers.removeAll() }
        if state == "archived" {
            catalog.editions[0].startDate = "2000-02-02"
            catalog.editions[0].endDate = "2000-02-04"
            catalog.editions[0].dateLabel = "2–4 February 2000"
            catalog.editions[0].slug = "2000"
            catalog.editions[0].label = "2000"
        }
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let slug = catalog.editions[0].slug
        let shouldShow = state == "approved" || state == "archived"
        for path in ["conferences/sample/index.html", "conferences/sample/\(slug)/index.html", "conferences/sample/\(slug)/access/index.html"] {
            let html = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(html.contains("id=\"support-indies\"") == shouldShow)
            if shouldShow {
                #expect(html.components(separatedBy: "id=\"support-indies\"").count == 2)
                #expect(html.contains("aria-labelledby=\"support-indies-title\""))
                #expect(html.contains("an honest App Store rating or review after you’ve tried them"))
                let access = try #require(html.range(of: "id=\"access-title\""))
                let thanks = try #require(html.range(of: "id=\"support-indies\""))
                #expect(access.lowerBound < thanks.lowerBound)
            }
        }
        for path in ["index.html", "participate/index.html"] {
            let html = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(!html.contains("id=\"support-indies\""))
        }
    }
}
