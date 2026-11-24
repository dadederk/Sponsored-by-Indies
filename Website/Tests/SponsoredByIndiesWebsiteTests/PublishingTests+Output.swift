import Foundation
import Ignite
import Testing

@testable import SponsoredByIndiesWebsite

extension PublishingTests {
    @Test(arguments: [true, false])
    func populatedPagesRespectApprovalAndEditionBoundaries(preview: Bool) async throws {
        var catalog = CatalogFixture.make()
        catalog.pressMention = PressMention(label: "Weekly & <Issue>", url: "https://example.org/issue?a=1&b=2", publishedOn: "2026-11-20", quote: preview ? "A kind & <thoughtful> idea." : nil, author: preview ? "Alex & <Writer>" : nil)
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
            #expect(!String(bundleHeading.output).contains("ARCtic"))
            #expect(!bundleSection.contains("About US$10 in savings"))
            #expect(!bundleSection.contains("We’re adding more to the bundle."))
            let valueSection = String(html[valuePosition.lowerBound..<accessPosition.lowerBound])
            let breakdown = try #require(valueSection.range(of: "<details[\\s\\S]*?</details>", options: .regularExpression))
            #expect(valueSection[breakdown].contains("A verified compatible saving."))
            #expect(valueSection[breakdown].contains("How we estimate the bundle’s value"))
            #expect(valueSection[breakdown].contains("US$10.00 × 100% = US$10.00"))
            let visibleValue = valueSection.replacingCharacters(in: breakdown, with: "")
            #expect(!visibleValue.contains("Tool &amp; &lt;Kit&gt;"))
            #expect(visibleValue.contains("Bundle value:"))
            #expect(visibleValue.contains("up to US$10"))
            #expect(visibleValue.components(separatedBy: "US$10").count == 2)
            #expect(!visibleValue.contains("About US$"))
            #expect(!visibleValue.contains("About US$10 in savings"))
            #expect(visibleValue.contains("We’re adding more to the bundle."))
            #expect(visibleValue.contains("get in touch"))
            #expect(visibleValue.contains("href=\"/participate/indies/\""))
            let cards = html.matches(of: /<article\b[^>]*class="panel product-card"[^>]*>[\s\S]*?<\/article>/).map { String($0.output) }
            #expect(cards.count == 2)
            let toolCard = try #require(cards.first { $0.contains("Tool &amp; &lt;Kit&gt;") })
            let deals = try #require(toolCard.firstMatch(of: /<ul[^>]*class="product-card-benefits"[^>]*>/))
            #expect(String(deals.output).contains("role=\"list\""))
            #expect(toolCard.contains("One year free."))
            #expect(toolCard.contains("Regular US price:"))
            #expect(toolCard.contains("for Tool &amp; &lt;Kit&gt;"))
            #expect(toolCard.contains("US$10.00 per year"))
            #expect(toolCard.contains("Sample plan"))
            #expect(!toolCard.contains("2026-11-13"))
            #expect(toolCard.contains("href=\"https://example.org/price\""))
            #expect(toolCard.range(of: #"<a href="https://example.org/tool"[^>]*>\s*<img[^>]*src="/optimized/app-icons/xarra.png""#, options: .regularExpression) != nil)
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
            #expect(html.components(separatedBy: "src=\"/optimized/app-icons/xarra.png\"").count == 2)
            #expect(html.contains("One year free."))
            #expect(html.contains("Sample Company"))
            #expect(html.contains("noindex, nofollow") == preview)
        }
        let home = try page("index.html")
        let directory = try page("conferences/index.html")
        let benefitsPosition = try #require(home.range(of: "id=\"benefits-title\""))
        let pressPosition = try #require(home.range(of: "id=\"press-feature\""))
        let communityPosition = try #require(home.range(of: "id=\"community-title\""))
        #expect(benefitsPosition.lowerBound < pressPosition.lowerBound)
        #expect(communityPosition.lowerBound < pressPosition.lowerBound)
        let introduction = home[..<benefitsPosition.lowerBound]
        #expect(!introduction.contains("Weekly &amp; &lt;Issue&gt;"))
        #expect(home.contains("<a href=\"https://example.org/issue?a=1&amp;b=2\">Weekly &amp; &lt;Issue&gt;</a>"))
        #expect(home.contains(">Featured in <a") == !preview)
        #expect(home.contains("A kind &amp; &lt;thoughtful&gt; idea.") == preview)
        #expect(home.contains("– Alex &amp; &lt;Writer&gt;") == preview)
        #expect(home.contains("<time datetime=\"2026-11-20T00:00:00Z\">20 November 2026</time>"))
        #expect(!directory.contains("Weekly &amp; &lt;Issue&gt;"))
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
        #expect(home.contains("/assets/brand/shared/by-indies-mark.svg?v=\(assetVersion)"))
        #expect(home.contains("/assets/icons/favicon.svg?v=\(assetVersion)"))
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
        #expect(contribution.contains("placeholder=\"ARCtic 2027\""))
        #expect(contribution.contains("placeholder=\"Get 70% off lifetime Premium for Xarra!"))
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
}
