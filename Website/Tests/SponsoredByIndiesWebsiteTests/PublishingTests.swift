import Foundation
import Ignite
import Testing

@testable import SponsoredByIndiesWebsite

// Ignite keeps a shared publishing context across suspension points. Serialize
// publishing tests while leaving the pure catalogue tests free to run in parallel.
@Suite(.serialized)
@MainActor
struct PublishingTests {
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

    private var source: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
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
            IndiePerson(name: "Ada & <Friends>", websiteURL: "https://example.org/ada?event=one&copy;=yes"),
            IndiePerson(name: "Ben Example", websiteURL: "https://example.org/ben")
        ]
        catalog.participations[0].quoteAttribution = QuoteAttribution(name: "Ben & <Team>", sourceURL: "https://example.org/quote?issue=81&copy;=yes")
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "conferences/sample/2027/index.html"), encoding: .utf8)
        let card = try #require(html.firstMatch(of: /<article class="panel product-card">[\s\S]*?<\/article>/))
        let text = String(card.output)
        #expect(text.contains("href=\"https://example.org/ada?event=one&amp;copy;=yes\""))
        #expect(text.contains(">Ada &amp; &lt;Friends&gt;</a>"))
        #expect(text.range(of: #"<a[^>]*href="https://example.org/ben"[^>]*>Ben Example</a>"#, options: .regularExpression) != nil)
        #expect(text.contains("href=\"https://example.org/maker\""))
        #expect(text.contains("Sample Company"))
        #expect(!text.contains("<Friends>"))
        let quote = try #require(text.firstMatch(of: /<blockquote[\s\S]*?<\/blockquote>/))
        #expect(String(quote.output).contains("href=\"https://example.org/quote?issue=81&amp;copy;=yes\""))
        #expect(String(quote.output).contains("Ben &amp; &lt;Team&gt;"))
        #expect(!String(quote.output).contains("<Team>"))
    }

    @Test(arguments: [true, false])
    func populatedPagesRespectApprovalAndEditionBoundaries(preview: Bool) async throws {
        var catalog = CatalogFixture.make()
        catalog.conferences[0].name = "Sample \"North\" & <Friends>"
        catalog.conferences[0].description = "A cool & <welcoming> conference."
        catalog.conferences[0].connectionEditions = ["2024", "2025 \"friends\" & crew"]
        catalog.editions[0].introduction = "An \"extra\" & useful bundle."
        catalog.contactURL = "mailto:team%26events@example.org"
        let editionID = "sample-\"2027\""
        catalog.editions[0].id = editionID
        catalog.participations[0].editionID = editionID
        catalog.offers[0].editionID = editionID
        var archived = catalog.editions[0]
        archived.id = "sample-2000"
        archived.slug = "2000"
        archived.label = "2000"
        archived.startDate = "2000-02-02"
        archived.endDate = "2000-02-04"
        catalog.editions.append(archived)
        var another = catalog.conferences[0]
        another.id = "another"
        another.slug = "another"
        another.name = "Another Conference"
        catalog.conferences.insert(another, at: 0)
        catalog.indies.append(
            Indie(
                id: "draft-maker", name: "UNAPPROVED MAKER",
                company: nil, websiteURL: nil, socials: [], initials: "UM"))
        catalog.participations.append(
            Participation(
                editionID: editionID, indieID: "draft-maker",
                connection: nil, quote: nil, publicationApproved: false))
        var draft = catalog.offers[0]
        draft.id = "draft-offer"
        draft.indieID = "draft-maker"
        draft.productName = "UNAPPROVED PRODUCT"
        draft.publicationApproved = false
        catalog.offers.append(draft)
        catalog.offers[0].productIconPath = "/app-icons/xarra.png"
        var alternative = catalog.offers[0]
        alternative.id = "tool-yearly"
        alternative.benefit = "One year free."
        catalog.offers.append(alternative)
        var secondProduct = catalog.offers[0]
        secondProduct.id = "game"
        secondProduct.productName = "A racing game"
        secondProduct.productURL = "https://example.org/game"
        secondProduct.productIconPath = nil
        secondProduct.benefit = "Free game."
        catalog.offers.append(secondProduct)
        catalog.editions[0].valueSummary = ValueSummary(
            explanation: "A verified compatible saving.", offerIDs: ["tool"])
        catalog.editions[0].bundleNote = "We’re adding more to the bundle."
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: preview, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)

        func page(_ path: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        }
        for path in ["conferences/sample/index.html", "conferences/sample/2027/index.html"] {
            let html = try page(path)
            #expect(html.contains("A &amp; B &lt;Studio&gt;"))
            #expect(html.contains("Tool &amp; &lt;Kit&gt;"))
            #expect(!html.contains("<Studio>"))
            #expect(!html.contains("<Kit>"))
            #expect(html.contains("A welcoming community."))
            for field in ["property=\"og:title\"", "name=\"twitter:title\""] {
                #expect(html.contains(field + " content=\"Sample &quot;North&quot; &amp;"))
            }
            for field in ["name=\"description\"", "property=\"og:description\"", "name=\"twitter:description\""] {
                #expect(html.contains(field + " content=\"An &quot;extra&quot; &amp; useful bundle.\""))
            }
            #expect(html.contains("A cool &amp; &lt;welcoming&gt; conference."))
            #expect(html.contains("For ticket holders."))
            let bundlePosition = try #require(html.range(of: "id=\"bundle\""))
            let valuePosition = try #require(html.range(of: "id=\"value\""))
            let accessPosition = try #require(html.range(of: "id=\"access\""))
            #expect(bundlePosition.lowerBound < valuePosition.lowerBound)
            #expect(valuePosition.lowerBound < accessPosition.lowerBound)
            let thanksPosition = try #require(html.range(of: "id=\"support-indies\""))
            let archivePosition = try #require(html.range(of: "id=\"other-editions\""))
            #expect(accessPosition.lowerBound < thanksPosition.lowerBound)
            #expect(thanksPosition.lowerBound < archivePosition.lowerBound)
            let bundleSection = String(html[bundlePosition.lowerBound..<valuePosition.lowerBound])
            let bundleHeading = try #require(bundleSection.firstMatch(of: /<h2[^>]*>[\s\S]*?<\/h2>/))
            #expect(String(bundleHeading.output).contains("Included with your"))
            #expect(String(bundleHeading.output).contains("Sample \"North\" &amp; &lt;Friends&gt; ticket."))
            #expect(!String(bundleHeading.output).contains("ARCTIC"))
            #expect(!bundleSection.contains("About US$10 in savings"))
            #expect(!bundleSection.contains("We’re adding more to the bundle."))
            let valueSection = String(html[valuePosition.lowerBound..<accessPosition.lowerBound])
            let breakdown = try #require(valueSection.range(of: "<details[\\s\\S]*?</details>", options: .regularExpression))
            #expect(valueSection[breakdown].contains("A verified compatible saving."))
            #expect(valueSection[breakdown].contains("How we estimate the bundle’s value"))
            #expect(valueSection[breakdown].contains("US$10.00 × 100% = US$10.00"))
            let visibleValue = valueSection.replacingCharacters(in: breakdown, with: "")
            #expect(!visibleValue.contains("Tool &amp; &lt;Kit&gt;"))
            #expect(visibleValue.contains("Potential value:"))
            #expect(visibleValue.components(separatedBy: "US$10").count == 2)
            #expect(!visibleValue.contains("About US$"))
            #expect(!visibleValue.contains("About US$10 in savings"))
            #expect(visibleValue.contains("We’re adding more to the bundle."))
            #expect(visibleValue.contains("get in touch"))
            #expect(visibleValue.contains("href=\"/participate/indies/\""))
            let cards = html.matches(of: /<article class="panel product-card">[\s\S]*?<\/article>/).map { String($0.output) }
            #expect(cards.count == 2)
            let toolCard = try #require(cards.first { $0.contains("Tool &amp; &lt;Kit&gt;") })
            let deals = try #require(toolCard.firstMatch(of: /<ul[^>]*class="product-card-benefits"[^>]*>/))
            #expect(String(deals.output).contains("role=\"list\""))
            #expect(toolCard.contains("One year free."))
            #expect(toolCard.contains("US reference price:"))
            #expect(toolCard.contains("for Tool &amp; &lt;Kit&gt;"))
            #expect(toolCard.contains("US$10.00 per year"))
            #expect(toolCard.contains("Sample plan"))
            #expect(!toolCard.contains("2026-11-13"))
            #expect(toolCard.contains("href=\"https://example.org/price\""))
            #expect(toolCard.range(of: #"<a href="https://example.org/tool"[^>]*>\s*<img[^>]*src="/app-icons/xarra.png""#, options: .regularExpression) != nil)
            #expect(!toolCard.contains("Free game."))
            #expect(toolCard.contains("data-offer-terms-fallback=\"true\""))
            let gameCard = try #require(cards.first { $0.contains("A racing game") })
            #expect(gameCard.contains("Free game."))
            #expect(gameCard.contains("for A racing game"))
            #expect(!gameCard.contains("One year free."))
            #expect(gameCard.contains("data-offer-terms-fallback=\"true\""))
            for card in cards {
                #expect(card.contains("A welcoming community."))
                #expect(card.contains("A &amp; B &lt;Studio&gt;"))
                let quotePosition = try #require(card.range(of: "A welcoming community."))
                let makerPosition = try #require(card.range(of: "A &amp; B &lt;Studio&gt;"))
                #expect(quotePosition.lowerBound < makerPosition.lowerBound)
                let trigger = try #require(card.firstMatch(of: /<a[^>]*href="#(offer-terms-[a-f0-9]+)"[^>]*>/))
                let modalID = String(trigger.1)
                #expect(String(trigger.0).contains("data-bs-toggle=\"modal\""))
                #expect(String(trigger.0).contains("aria-haspopup=\"dialog\""))
                #expect(String(trigger.0).contains("aria-controls=\"\(modalID)\""))
                #expect(card.contains("id=\"\(modalID)\" tabindex=\"-1\" class=\"modal\""))
                #expect(card.contains("id=\"\(modalID)-title\""))
                let fallback = try #require(card.firstMatch(of: /<details[^>]*data-offer-terms-fallback="true"[^>]*>/))
                #expect(String(fallback.output).contains("id=\"\(modalID)-fallback\""))
                #expect(!String(fallback.output).contains("hidden"))
                #expect(card.contains("data-offer-terms-trigger=\"true\" hidden"))
                #expect(card.contains("data-bs-dismiss=\"modal\""))
                #expect(card.contains("modal-dialog-scrollable"))
            }
            #expect(html.contains("src=\"/offer-terms.mjs\""))
            #expect(html.components(separatedBy: "src=\"/app-icons/xarra.png\"").count == 2)
            #expect(html.contains("One year free."))
            #expect(html.contains("Sample Company"))
            #expect(html.contains("noindex, nofollow") == preview)
        }
        let home = try page("index.html")
        let directory = try page("conferences/index.html")
        #expect(home.contains("What’s in it"))
        #expect(!directory.contains("What’s in it"))
        #expect(directory.contains("id=\"benefits-title\""))
        #expect(directory.contains("Get <span class=\"title-accent\">involved.</span>"))
        func audienceCards(in html: String) -> [String] {
            html.matches(of: /<article class="panel">[\s\S]*?<\/article>/).map { String($0.output) }
        }
        let homeCards = audienceCards(in: home)
        let directoryCards = audienceCards(in: directory)
        let participationCards = audienceCards(in: try page("participate/index.html"))
        #expect(homeCards.count == 3)
        #expect(directoryCards.count == 2)
        #expect(participationCards.count == 3)
        for (card, audience) in zip(participationCards, ["For conference organisers", "For independent makers", "For attendees"]) {
            #expect(card.contains(audience))
            #expect(card.contains("<h2 "))
            let nestedCard = card.replacingOccurrences(of: "<h2 ", with: "<h3 ")
                .replacingOccurrences(of: "</h2>", with: "</h3>")
            #expect(homeCards.contains(nestedCard))
        }
        #expect(!directoryCards.contains { $0.contains("For attendees") })
        for audience in ["For conference organisers", "For independent makers"] {
            let homeCard = try #require(homeCards.first { $0.contains(audience) })
            let directoryCard = try #require(directoryCards.first { $0.contains(audience) })
            #expect(homeCard == directoryCard)
        }
        let terms = try page("terms/index.html")
        #expect(terms.contains("Community &amp; &lt;care&gt;."))
        #expect(terms.contains("Shared &lt;responsibilities&gt;"))
        #expect(terms.contains("A &amp; B act independently."))
        #expect(!terms.contains("<care>"))
        #expect(terms.contains("mailto:team%26events@example.org"))
        let assetVersion = try AssetFingerprint.make(in: source)
        #expect(home.contains("/styles.css?v=tokens-\(assetVersion)"))
        #expect(home.contains("/logo.svg?v=shared-imprint-01-\(assetVersion)"))
        #expect(home.contains("/favicon-shared-imprint-01.svg?v=\(assetVersion)"))
        #expect(home.contains("data-next-edition=\"sample-&quot;2027&quot;\""))
        let contribution = try page("participate/indies/index.html")
        let conferenceInterest = try page("participate/conferences/index.html")
        for html in [contribution, conferenceInterest] {
            let disclosure = try #require(html.firstMatch(of: /<details[^>]*id="interest-form"[^>]*>/))
            #expect(!String(disclosure.output).contains(" open"))
            #expect(html.contains("<summary>Prefer a form?</summary>"))
            #expect(html.contains("id=\"form-fallback\""))
        }
        let conferenceRequired = conferenceInterest.matches(of: /<(?:input|textarea|select)[^>]*required[^>]*>/).map { String($0.output) }
        #expect(conferenceRequired.count == 3)
        for id in ["organiser-name", "organiser-email", "conference-name"] {
            #expect(conferenceRequired.contains { $0.contains("id=\"\(id)\"") })
        }
        #expect(conferenceInterest.contains("src=\"/conference-interest.mjs\""))
        #expect(!conferenceInterest.contains(">Tell us about your conference</a>"))
        let directEmail = try #require(contribution.range(
            of: "<a[^>]*href=\"([^\"]*)\"[^>]*>Express indie interest</a>", options: .regularExpression))
        let buttonMarkup = String(contribution[directEmail])
        let href = try #require(buttonMarkup.firstMatch(of: /href="([^"]*)"/)?.1)
        let emailURL = try #require(URLComponents(string: String(href).replacingOccurrences(of: "&amp;", with: "&")))
        #expect(emailURL.scheme == "mailto")
        #expect(emailURL.path == "team&events@example.org")
        #expect(emailURL.queryItems?.first { $0.name == "subject" }?.value == "Sponsored by Indies — indie contribution")
        let emailBody = try #require(emailURL.queryItems?.first { $0.name == "body" }?.value)
        for prompt in ["Name:", "Conference and year:", "Product name and link:", "What I’d like to offer:", "Anything else you’d like us to know (optional):"] {
            #expect(emailBody.contains(prompt))
        }
        for (attribute, expectedRole) in [
            ("data-add-offer", "btn-secondary"),
            ("data-remove-icon", "btn-secondary"),
            ("data-remove-offer", "btn-danger"),
            ("data-remove-resource", "btn-danger")
        ] {
            let range = try #require(contribution.range(
                of: "<button[^>]*\(attribute)=\"true\"[^>]*>.*?</button>",
                options: .regularExpression
            ))
            let button = String(contribution[range])
            #expect(button.contains("type=\"button\""))
            #expect(button.contains(expectedRole))
            #expect(button.contains("aria-hidden=\"true\""))
            #expect(button.contains("data-action-label=\"true\""))
        }
        #expect(contribution.contains("aria-label=\"Add another offer to contribution 1\""))
        #expect(contribution.contains("aria-label=\"Remove image from contribution 1\""))
        // The initial proposal only needs identity, conference and one free-text offer.
        let requiredControls = contribution.matches(of: /<(?:input|textarea|select)[^>]*required[^>]*>/).map { String($0.output) }
        #expect(requiredControls.count == 4)
        for id in ["maker-name", "maker-email", "conference", "resource-1-offer-1-proposal"] {
            #expect(requiredControls.contains { $0.contains("id=\"\(id)\"") })
        }
        for summary in ["More about you (optional)", "Your connection and quote (optional)", "Product details and icon (optional)"] {
            #expect(contribution.contains("<summary>\(summary)</summary>"))
        }
        #expect(contribution.contains("1. App, game or other resource"))
        #expect(contribution.contains("1. Offer"))
        #expect(contribution.contains("placeholder=\"Dani Devesa\""))
        #expect(contribution.contains("placeholder=\"ARCTIC 2027\""))
        #expect(contribution.contains("placeholder=\"Get 50% off lifetime Premium for Xarra!"))
        #expect(contribution.contains("aria-describedby=\"connection-help\""))
        #expect(!contribution.contains("RocketSim"))
        #expect(!contribution.contains("<details open"))
        #expect(contribution.contains("type=\"file\""))
        #expect(contribution.contains("data-product-icon=\"true\""))
        #expect(contribution.contains("accept=\"image/png,image/jpeg,image/webp\""))
        #expect(contribution.contains("/css/bootstrap-icons.min.css"))
        #expect(contribution.contains("value=\"Sample &quot;North&quot; &amp;"))
        let suggestionsRange = try #require(contribution.range(of: "<datalist[^>]*id=\"conference-options\"[^>]*>.*?</datalist>", options: .regularExpression))
        let suggestions = String(contribution[suggestionsRange])
        #expect(!suggestions.contains("2024"))
        #expect(!suggestions.contains("2025 &quot;friends&quot; &amp; crew"))
        #expect(suggestions.contains("2027"))
        #expect(!suggestions.contains("2000"))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("conferences/sample/2024/index.html").path))
        #expect(contribution.contains("data-recipient=\"team&amp;events@example.org\""))
        let access = try page("conferences/sample/2027/access/index.html")
        #expect(access.contains("Each product card includes its offer terms and redemption guidance."))
        #expect(!access.contains("For ticket holders."))
        #expect(access.contains("https://example.org/attendees"))
        #expect(access.contains(preview ? "noindex, nofollow" : "noindex, follow"))
        for path in ["conferences/sample/2000/index.html", "conferences/another/index.html"] {
            let html = try page(path)
            #expect(!html.contains("Tool &amp; &lt;Kit&gt;"))
            #expect(!html.contains("A &amp; B &lt;Studio&gt;"))
        }
        func generatedHTML() throws -> [String] {
            let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            return try enumerator.compactMap { entry in
                guard let file = entry as? URL, file.pathExtension == "html" else { return nil }
                return try String(contentsOf: file, encoding: .utf8)
            }
        }
        for html in try generatedHTML() {
            #expect(html.contains("href=\"/terms/\""))
            #expect(!html.contains("UNAPPROVED MAKER"))
            #expect(!html.contains("UNAPPROVED PRODUCT"))
        }
    }

    @Test(arguments: ["2027-02-04", "2027-02-05", "2029-01-01"])
    func searchMetadataFollowsFeaturedEdition(day: String) async throws {
        var catalog = CatalogFixture.make()
        var next = catalog.editions[0]
        next.id = "sample-2028"
        next.slug = "2028"
        next.label = "2028"
        next.startDate = "2028-02-02"
        next.endDate = "2028-02-04"
        catalog.editions.append(next)
        var empty = catalog.conferences[0]
        empty.id = "empty"
        empty.slug = "empty"
        catalog.conferences.append(empty)
        try catalog.validate()
        let date = try #require(ISO8601DateFormatter().date(from: day + "T12:00:00Z"))
        let expectedYear = day == "2027-02-04" ? "2027" : "2028"
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: false, url: try #require(URL(string: "https://custom.example.org")), publicationDate: date)
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let hub = try String(contentsOf: root.appending(path: "conferences/sample/index.html"), encoding: .utf8)
        let canonical = "https://custom.example.org/conferences/sample/\(expectedYear)/"
        #expect(hub.contains("href=\"\(canonical)\" rel=\"canonical\""))
        #expect(hub.contains("property=\"og:url\" content=\"\(canonical)\""))
        #expect(hub.components(separatedBy: "rel=\"canonical\"").count == 2)
        #expect(hub.components(separatedBy: "property=\"og:url\"").count == 2)
        let home = try String(contentsOf: root.appending(path: "index.html"), encoding: .utf8)
        #expect(home.contains("<title>Indie bundles for Swift &amp; iOS conferences"))
        #expect(home.contains("content=\"https://custom.example.org/social-preview.png?v="))
        let directory = try String(contentsOf: root.appending(path: "conferences/index.html"), encoding: .utf8)
        let contribution = try String(contentsOf: root.appending(path: "participate/indies/index.html"), encoding: .utf8)
        #expect(contribution.contains("value=\"Sample Conference 2027\"") == (day <= "2027-02-04"))
        #expect(contribution.contains("value=\"Sample Conference 2028\"") == (day <= "2028-02-04"))
        #expect(directory.contains("href=\"/conferences/sample/\(expectedYear)/\""))
        let sitemap = try String(contentsOf: root.appending(path: "sitemap.xml"), encoding: .utf8)
        #expect(!sitemap.contains("<loc>https://custom.example.org/conferences/sample/</loc>"))
        #expect(!sitemap.contains("/access/"))
        #expect(sitemap.contains("<loc>https://custom.example.org/conferences/empty/</loc>"))
        for year in ["2027", "2028"] {
            #expect(sitemap.contains("<loc>https://custom.example.org/conferences/sample/\(year)/</loc>"))
            let edition = try String(contentsOf: root.appending(path: "conferences/sample/\(year)/index.html"), encoding: .utf8)
            #expect(edition.contains("href=\"https://custom.example.org/conferences/sample/\(year)/\" rel=\"canonical\""))
        }
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
        let card = try #require(html.firstMatch(of: /<article class="panel product-card">[\s\S]*?<\/article>/))
        let instructions = "Open the lifetime &amp; member portal."
        let fallback = try #require(String(card.output).firstMatch(of: /<details[\s\S]*?<\/details>/))
        let dialog = String(card.output).components(separatedBy: String(fallback.output))[0]
        #expect(dialog.components(separatedBy: instructions).count == 2)
        #expect(String(fallback.output).components(separatedBy: instructions).count == 2)
        if !shared {
            let sections = String(card.output).matches(of: /<div class="mb-[^"]*">[\s\S]*?<\/div>/).map { String($0.output) }
            let lifetime = try #require(sections.first { $0.contains("Lifetime discount") })
            let yearly = try #require(sections.first { $0.contains("Free year") })
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

    @Test(arguments: [nil, "https://example.org/contact?source=indies&lang=en"] as [String?])
    func participationInterestMatchesTheConfiguredContactRoute(contact: String?) async throws {
        var catalog = CatalogFixture.make()
        catalog.contactURL = contact
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "participate/indies/index.html"), encoding: .utf8)
        #expect(!html.contains("id=\"contribution-form\""))
        #expect(!html.contains("src=\"/contribution.mjs\""))
        #expect(!html.contains("Opens an email draft."))
        #expect(!html.contains("use the form below"))
        #expect(html.contains("A contribution contact route will be available here soon.") == (contact == nil))
        #expect(html.contains("Express indie interest") == (contact != nil))
        if let contact {
            #expect(html.contains("href=\"\(escaped(contact))\""))
            #expect(html.contains("through our contact page."))
        }
        let conference = try String(contentsOf: root.appending(path: "participate/conferences/index.html"), encoding: .utf8)
        #expect(!conference.contains("id=\"conference-interest-form\""))
        #expect(!conference.contains("src=\"/conference-interest.mjs\""))
        #expect(!conference.contains("Prefer a form?"))
        #expect(!conference.contains("Opens an email draft."))
        #expect(conference.contains("A conference contact route will be available here soon.") == (contact == nil))
        #expect(conference.contains("Express conference interest") == (contact != nil))
        if let contact { #expect(conference.contains("href=\"\(escaped(contact))\"")) }
    }

    @Test func textareaOptionsComposeIndependently() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = FormOptionsSite(url: try #require(URL(string: "https://example.org")))
        try await site.publish(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appendingPathComponent("index.html"), encoding: .utf8)
        for index in 0..<8 {
            let range = try #require(html.range(of: "<textarea[^>]*id=\"field-\(index)\"[^>]*>", options: .regularExpression))
            let control = String(html[range])
            #expect((control.range(of: "\\srequired(?:\\s|=|>)", options: .regularExpression) != nil) == (index & 1 != 0))
            #expect((control.range(of: "\\sreadonly(?:\\s|=|>)", options: .regularExpression) != nil) == (index & 2 != 0))
            #expect(control.contains("data-resource-field=\"description\"") == (index & 4 != 0))
            #expect(control.contains("aria-describedby=\"help\""))
            #expect(html.contains("for=\"field-\(index)\""))
        }
    }
}

private struct FormOptionsSite: Site {
    let url: URL
    var name = "Form option checks"
    var layout = MarketingLayout(preview: true)
    var feedConfiguration: FeedConfiguration? = nil
    var builtInIconsEnabled: BootstrapOptions = .none
    var homePage: MarketingPage {
        MarketingPage(path: "/", title: "Form option checks", description: "Synthetic form controls.") {
            Text("Form option checks").font(.title1)
            Text("Field help").id("help")
            for index in 0..<8 {
                FormFields.multiline(
                    "Field \(index)", id: "field-\(index)", required: index & 1 != 0,
                    readOnly: index & 2 != 0, resourceKey: index & 4 != 0 ? "description" : nil,
                    helpID: "help")
            }
        }
    }
}


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
    func showcaseLabelsConferenceDatesAtBothBoundaries(day: String) async throws {
        let labels = ["2027-02-01": "Upcoming conference", "2027-02-02": "Current conference",
                      "2027-02-04": "Current conference", "2027-02-05": "Past conference"]
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: CatalogFixture.showcase(), preview: true,
                              url: try #require(URL(string: SiteIdentity.showcase.previewURL)),
                              publicationDate: try Date(day, strategy: Edition.dayStyle), identity: .showcase)
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "index.html"), encoding: .utf8)
        #expect(html.contains(try #require(labels[day])))
    }

    @Test(arguments: [true, false])
    func showcasePublishesProjectsBuildersAndDirectBundleLinks(preview: Bool) async throws {
        var catalog = CatalogFixture.showcase()
        catalog.indies[0].people = [
            IndiePerson(name: "One & <Builder>", websiteURL: "https://example.org/one?x=1&y=2", bio: "Makes useful & <thoughtful> things.", portraitPath: "/portraits/dani-devesa.jpg"),
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
        #expect(html.contains("Makes useful &amp; &lt;thoughtful&gt; things."))
        #expect(html.contains("A longer project story &amp; &lt;details&gt;."))
        #expect(html.contains("/portraits/dani-devesa.jpg"))
        #expect(html.contains("builder-initials"))
        #expect(html.contains("Meet the builders"))
        #expect(!html.contains("Sample Company"))
        #expect(html.contains("Website<span class=\"visually-hidden\"> for One &amp; &lt;Builder&gt;</span>"))
        #expect(html.contains("Social &amp; &lt;more&gt;<span class=\"visually-hidden\"> for Two Builder</span>"))
        #expect(html.contains("Past conference"))
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
