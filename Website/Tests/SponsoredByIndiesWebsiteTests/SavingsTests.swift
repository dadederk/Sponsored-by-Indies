import Foundation
import Testing

@testable import SponsoredByIndiesWebsite

struct SavingsTests {
    @Test(arguments: [("69.99", 30, "20.99"), ("29.99", 50, "14.99"), ("29.99", 100, "29.99"), ("0.01", 30, "0")])
    func savingsUseDecimalArithmeticAndConservativeCents(price: String, percent: Int, saving: String) throws {
        let evidence = CatalogFixture.saving(price: try #require(Decimal(string: price)), percent: percent)
        #expect(evidence.amountUSD == Decimal(string: saving))
        #expect(evidence.offerPriceUSD + evidence.amountUSD == evidence.regularPriceUSD)
    }

    @Test(arguments: [("29.99", 50, "15.00"), ("69.99", 30, "49.00"), ("29.99", 100, "0"), ("0.01", 30, "0.01")])
    func estimatedPaymentDoesNotOverstateTheDiscount(price: String, percent: Int, payment: String) throws {
        let evidence = CatalogFixture.saving(price: try #require(Decimal(string: price)), percent: percent)
        #expect(evidence.offerPriceUSD == Decimal(string: payment))
    }

    @Test func makerConfirmedPriceControlsPaymentSavingAndBundleValue() throws {
        var catalog = CatalogFixture.make()
        var evidence = CatalogFixture.saving(price: Decimal(string: "69.99")!, percent: 30)
        evidence.confirmedOfferPriceUSD = Decimal(string: "48.99")!
        catalog.offers[0].savingEstimate = evidence
        catalog.editions[0].valueSummary = ValueSummary(explanation: "Confirmed offer.", offerIDs: [catalog.offers[0].id])
        try catalog.validate()
        #expect(evidence.offerPriceUSD == Decimal(string: "48.99"))
        #expect(evidence.amountUSD == 21)
        #expect(catalog.bundleValue(for: catalog.editions[0])?.totalUSD == 21)
        #expect(evidence.calculationDescription.contains("US$69.99 − US$48.99"))
    }

    @Test(arguments: ["-1", "70", "48.991", "47.99", "NaN"])
    func rejectsInvalidOrInconsistentConfirmedPrices(price: String) throws {
        var catalog = CatalogFixture.make()
        var evidence = CatalogFixture.saving(price: Decimal(string: "69.99")!, percent: 30)
        if price == "NaN" {
            evidence.confirmedOfferPriceUSD = .nan
        } else {
            let confirmedPrice: Decimal = try #require(Decimal(string: price))
            evidence.confirmedOfferPriceUSD = confirmedPrice
        }
        catalog.offers[0].savingEstimate = evidence
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test(arguments: ["0", "0.01"])
    func confirmedFreeOffersCannotUseTheRoundingAllowance(price: String) throws {
        var catalog = CatalogFixture.make()
        var evidence = CatalogFixture.saving(price: Decimal(string: "0.01")!, percent: 100)
        let confirmedPrice: Decimal = try #require(Decimal(string: price))
        evidence.confirmedOfferPriceUSD = confirmedPrice
        catalog.offers[0].savingEstimate = evidence
        if price == "0" {
            try catalog.validate()
            #expect(evidence.offerPriceLabel == "Free for the first year")
        } else {
            #expect(throws: CatalogError.self) { try catalog.validate() }
        }
    }

    @Test func renewalUsesTheFutureRegularPriceUnlessAnOfferSpecifiesOtherwise() throws {
        var catalog = CatalogFixture.make()
        #expect(catalog.offers[0].renewalDescription == "After the first year, the regular price at renewal applies.")
        catalog.offers[0].renewalTerms = "The discount continues at renewal."
        try catalog.validate()
        #expect(catalog.offers[0].renewalDescription == "The discount continues at renewal.")
        catalog.offers[0].renewalTerms = " "
        #expect(throws: CatalogError.self) { try catalog.validate() }
        catalog.offers[0].renewalTerms = nil
        catalog.offers[0].savingEstimate?.period = .lifetime
        #expect(catalog.offers[0].renewalDescription == nil)
        catalog.offers[0].renewalTerms = "Renew next year."
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func loadingPreservesAnOffersCustomRenewalTerms() throws {
        let files = FileManager.default
        let website = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let root = files.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? files.removeItem(at: root) }
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        for folder in ["Data", "Assets"] {
            try files.copyItem(at: website.appending(path: folder), to: root.appending(path: folder))
        }
        let recordURL = root.appending(path: "Data/Conferences/arctic.json")
        let source = try String(contentsOf: recordURL, encoding: .utf8)
        let offerID = #""id": "xarra-yearly","#
        try #require(source.contains(offerID))
        let renewalTerms = "This offer does not renew automatically."
        let encodedTerms = String(decoding: try JSONEncoder().encode(renewalTerms), as: UTF8.self)
        // Preserve decimal price literals while adding the optional field.
        try source.replacingOccurrences(of: offerID, with: "\(offerID)\n      \"renewalTerms\": \(encodedTerms),")
            .write(to: recordURL, atomically: true, encoding: .utf8)

        let catalog = try Catalog.load(from: root.appending(path: "Data"))
        let offer = try #require(catalog.offers.first { $0.id == "xarra-yearly" })
        #expect(offer.renewalDescription == renewalTerms)
    }

    @Test func priceLabelsDistinguishAnnualLifetimeAndOneTimeOffers() throws {
        var estimate = CatalogFixture.saving(price: Decimal(string: "29.99")!, percent: 100)
        #expect(estimate.offerPriceLabel == "Free for the first year")
        estimate.period = .lifetime
        estimate.discountPercent = 50
        #expect(estimate.offerPriceLabel == "US$15.00 for lifetime access")
        estimate.period = .oneTime
        estimate.discountPercent = 100
        #expect(estimate.offerPriceLabel == "Free")
        estimate.discountPercent = 50
        #expect(estimate.offerPriceLabel == "US$15.00 one-time purchase")
    }

    @Test func bundleValueIsComputedAndCannotCountAlternativeOffersTwice() throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].savingEstimate = CatalogFixture.saving(price: Decimal(string: "29.99")!, percent: 50)
        var alternative = catalog.offers[0]
        alternative.id = "year"
        alternative.savingEstimate = CatalogFixture.saving(price: Decimal(string: "9.99")!)
        catalog.offers.append(alternative)
        catalog.editions[0].valueSummary = ValueSummary(explanation: "Compatible offers only.", offerIDs: ["tool"])
        try catalog.validate()
        #expect(catalog.bundleValue(for: catalog.editions[0])?.totalUSD == Decimal(string: "14.99"))
        #expect(catalog.bundleValue(for: catalog.editions[0])?.amountLabel == "US$14")
        catalog.editions[0].valueSummary?.offerIDs = ["tool", "year"]
        #expect(throws: CatalogError.self) { try catalog.validate() }
        catalog.editions[0].valueSummary?.offerIDs = ["year"]
        #expect(throws: CatalogError.self) { try catalog.validate() }
        catalog.editions[0].valueSummary?.offerIDs = ["tool"]
        catalog.offers[0].savingEstimate = nil
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func catalogueTotalsAndRankingUseTheSamePriceEvidence() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Data")
        let catalog = try Catalog.load(from: directory)
        let edition = try #require(catalog.editions.first { $0.id == "arctic-2027" })
        let products = catalog.visibleProductContributions(for: edition)
        #expect(products.map(\.product.productName) == ["Swift & SwiftUI books", "The Shed", "Nunch", "Structured", "AI Fundamentals", "Whio", "Passable", "Dee: Muay Thai Coach", "Helm", "PocketShelf", "Kickstart", "RocketSim for Xcode", "RocketTrace for Xcode", "Xarra!", "SwiftData Architecture", "SwiftUI Architecture", "Movie Buzz", "LookUp", "Coca", "RetroRapid!"])
        let value = try #require(catalog.bundleValue(for: edition))
        #expect(value.totalUSD == products.reduce(0) { $0 + ($1.maximumSavingUSD ?? 0) })
        #expect(value.totalUSD == Decimal(string: "606.00"))
        #expect(value.amountLabel == "US$606")
        let structured = try #require(products.first { $0.product.projectID == "structured" })
        #expect(structured.offers.count == 2)
        #expect(value.offers.filter { $0.projectID == "structured" }.map(\.id) == ["structured-lifetime"])
        let structuredLifetime = try #require(structured.offers.first { $0.id == "structured-lifetime" }?.savingEstimate)
        #expect(structuredLifetime.discountPercent == 50)
        #expect(structuredLifetime.regularPriceUSD == Decimal(string: "99.99"))
        #expect(structuredLifetime.amountUSD == Decimal(string: "49.99"))
        #expect(structuredLifetime.offerPriceUSD == 50)
        let structuredYear = try #require(structured.offers.first { $0.id == "structured-yearly" })
        #expect(structuredYear.benefit == "1 year of Pro free")
        // An ambiguous yearly price must not replace the reviewed lifetime estimate.
        #expect(structuredYear.savingEstimate == nil)
        let azamBooks = value.offers.filter { $0.indieID == "mohammad-azam" }
        #expect(Set(azamBooks.compactMap(\.projectID)) == ["swiftui-architecture", "swiftdata-architecture"])
        #expect(azamBooks.reduce(0) { $0 + ($1.savingEstimate?.amountUSD ?? 0) } == 39)
        for book in azamBooks {
            let evidence = try #require(book.savingEstimate)
            #expect(evidence.regularPriceUSD == 39)
            #expect(evidence.discountPercent == 50)
            #expect(evidence.period == .oneTime)
            #expect(evidence.offerPriceUSD == Decimal(string: "19.50"))
            #expect(evidence.sourceFormat == .manual)
        }
        let lookup = try #require(value.offers.first { $0.projectID == "lookup" }?.savingEstimate)
        #expect(lookup.plan == "LookUp+ Yearly")
        #expect(lookup.period == .year)
        #expect(lookup.discountPercent == 30)
        #expect(lookup.amountUSD == Decimal(string: "8.99"))
        #expect(lookup.offerPriceUSD == 21)
        let movieBuzz = try #require(value.offers.first { $0.projectID == "movie-buzz" }?.savingEstimate)
        #expect(movieBuzz.plan == "Movie Buzz 70mm Annual")
        #expect(movieBuzz.period == .year)
        #expect(movieBuzz.discountPercent == 50)
        #expect(movieBuzz.amountUSD == Decimal(string: "9.99"))
        #expect(movieBuzz.offerPriceUSD == 10)
        #expect(!catalog.projects.contains { $0.id == "deck-man" })
        #expect(!catalog.offers.contains { $0.projectID == "deck-man" })
        let kickstart = try #require(value.offers.first { $0.projectID == "kickstart" }?.savingEstimate)
        #expect(kickstart.plan == "Kickstart Pro Yearly")
        #expect(kickstart.regularPriceUSD == Decimal(string: "69.99"))
        #expect(kickstart.discountPercent == 30)
        #expect(kickstart.period == .year)
        #expect(kickstart.discountedPeriods == 1)
        #expect(kickstart.confirmedOfferPriceUSD == Decimal(string: "48.99"))
        #expect(kickstart.amountUSD == 21)
        #expect(kickstart.offerPriceUSD == Decimal(string: "48.99"))
        let whio = try #require(products.first { $0.product.projectID == "whio" })
        #expect(whio.offers.count == 2)
        #expect(whio.maximumSavingUSD == Decimal(string: "44.99"))
        #expect(value.offers.filter { $0.projectID == "whio" }.map(\.id) == ["whio-lifetime"])
        let books = try #require(value.offers.first { $0.projectID == "nil-coalescing-books" }?.savingEstimate)
        #expect(books.regularPriceUSD == 155)
        #expect(books.amountUSD == Decimal(string: "77.50"))
        #expect(books.plan == "The Full Bundle")
        #expect(books.sourceFormat == .manual)
        let nunch = try #require(products.first { $0.product.projectID == "nunch" })
        #expect(nunch.offers.count == 2)
        #expect(nunch.maximumSavingUSD == Decimal(string: "49.99"))
        #expect(value.offers.filter { $0.projectID == "nunch" }.map(\.id) == ["nunch-lifetime"])
        let nunchLifetime = try #require(nunch.offers.first { $0.id == "nunch-lifetime" }?.savingEstimate)
        #expect(nunchLifetime.plan == "Nunch Lifetime")
        #expect(nunchLifetime.discountPercent == 50)
        #expect(nunchLifetime.offerPriceUSD == 50)
        let nunchYear = try #require(nunch.offers.first { $0.id == "nunch-yearly" }?.savingEstimate)
        #expect(nunchYear.discountPercent == 100)
        #expect(nunchYear.amountUSD == Decimal(string: "34.99"))
        #expect(nunchYear.offerPriceUSD == 0)
        let shed = try #require(products.first { $0.product.projectID == "the-shed" })
        #expect(shed.offers.count == 2)
        #expect(shed.maximumSavingUSD == Decimal(string: "62.49"))
        #expect(value.offers.filter { $0.projectID == "the-shed" }.map(\.id) == ["the-shed-lifetime"])
        let shedLifetime = try #require(shed.offers.first { $0.id == "the-shed-lifetime" }?.savingEstimate)
        #expect(shedLifetime.plan == "The Shed Pro – Lifetime")
        #expect(shedLifetime.offerPriceUSD == Decimal(string: "62.50"))
        let shedYear = try #require(shed.offers.first { $0.id == "the-shed-yearly" }?.savingEstimate)
        #expect(shedYear.plan == "The Shed Pro – Yearly")
        #expect(shedYear.amountUSD == Decimal(string: "49.99"))
        #expect(shedYear.offerPriceUSD == 0)
        let shelf = try #require(products.first { $0.product.projectID == "pocketshelf" })
        #expect(shelf.offers.count == 2)
        #expect(shelf.maximumSavingUSD == Decimal(string: "24.99"))
        #expect(value.offers.filter { $0.projectID == "pocketshelf" }.map(\.id) == ["pocketshelf-lifetime"])
        let passable = try #require(products.first { $0.product.projectID == "passable" })
        #expect(passable.offers.count == 2)
        #expect(passable.maximumSavingUSD == Decimal(string: "39.99"))
        #expect(value.offers.filter { $0.projectID == "passable" }.map(\.id) == ["passable-yearly"])
        #expect(value.offers.first { $0.projectID == "coca" }?.savingEstimate?.amountUSD == Decimal(string: "3.89"))
        let xarra = try #require(value.offers.first { $0.id == "xarra-lifetime" }?.savingEstimate)
        #expect(xarra.discountPercent == 70)
        #expect(xarra.amountUSD == Decimal(string: "20.99"))
        #expect(xarra.offerPriceUSD == 9)
        #expect(value.offers.first { $0.id == "rocketsim-yearly" }?.savingEstimate?.review == .provisional)
        let course = try #require(value.offers.first { $0.id == "ai-fundamentals-course" }?.savingEstimate)
        #expect(course.regularPriceUSD == 199)
        #expect(course.discountPercent == 25)
        #expect(course.period == .lifetime)
        #expect(course.sourceFormat == .schemaOrg)
        #expect(course.amountUSD == Decimal(string: "49.75"))
        let trace = try #require(value.offers.first { $0.id == "rockettrace-yearly" }?.savingEstimate)
        #expect(trace.discountPercent == 30)
        #expect(trace.period == .year)
        #expect(trace.amountUSD == Decimal(string: "20.99"))
        let helm = try #require(value.offers.first { $0.id == "helm-yearly" }?.savingEstimate)
        #expect(helm.regularPriceUSD == Decimal(string: "54.99"))
        #expect(helm.discountPercent == 50)
        #expect(helm.period == .year)
        #expect(helm.discountedPeriods == 1)
        #expect(helm.plan == "Helm Pro Year")
        #expect(helm.amountUSD == Decimal(string: "27.49"))
        #expect(helm.offerPriceUSD == Decimal(string: "27.50"))
        let maker = catalog.indie(withID: "anima-software")
        #expect(maker.name == "Hidde & Pol")
        #expect(maker.company == "Anima Software")
        #expect(maker.websiteURL == "https://helm-app.com/")
        #expect(maker.people?.map(\.name) == ["Hidde van der Ploeg", "Pol Piella"])
        #expect(maker.people?.map(\.websiteURL) == ["https://hidde.design/", "https://www.polpiella.dev/"])
        #expect(catalog.visibleParticipations(for: edition).first { $0.indieID == maker.id }?.connection == "Speakers ARCtic 2025")
    }

    @Test(arguments: ["currency", "storefront", "percentage zero", "percentage too large", "duration", "missing plan", "missing observations", "wrong selection", "duplicate observation", "unreviewed ambiguity", "foreign storefront link"])
    func rejectsInconsistentPriceEvidence(field: String) throws {
        var catalog = CatalogFixture.make()
        var evidence = try #require(catalog.offers[0].savingEstimate)
        switch field {
        case "currency": evidence.currency = "GBP"
        case "storefront": evidence.storefront = "GB"
        case "percentage zero": evidence.discountPercent = 0
        case "percentage too large": evidence.discountPercent = 101
        case "duration": evidence.discountedPeriods = 2
        case "missing plan": evidence.plan = " "
        case "missing observations": evidence.observedPricesUSD = []
        case "wrong selection": evidence.observedPricesUSD = [20]
        case "duplicate observation": evidence.observedPricesUSD = [10, 10]
        case "unreviewed ambiguity": evidence.observedPricesUSD = [10, 20]
        default: evidence.sourceURL = "https://apps.apple.com/gb/app/tool/id123"
        }
        catalog.offers[0].savingEstimate = evidence
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func ambiguityIsRetainedWithoutGuessingItsMeaning() throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].savingEstimate?.observedPricesUSD = [10, 20]
        catalog.offers[0].savingEstimate?.review = .provisional
        try catalog.validate()
    }

    @Test func futureAndOldPricesFailWhileArchivedEditionsRetainTheirHistoricalEvidence() throws {
        var catalog = CatalogFixture.make()
        try catalog.validatePriceFreshness(on: Date("2026-12-13", strategy: Edition.dayStyle))
        #expect(throws: CatalogError.self) {
            try catalog.validatePriceFreshness(on: Date("2026-12-14", strategy: Edition.dayStyle))
        }
        #expect(throws: CatalogError.self) {
            try catalog.validatePriceFreshness(on: Date("2026-11-12", strategy: Edition.dayStyle))
        }
        catalog.editions[0].endDate = "2026-11-10"
        try catalog.validatePriceFreshness(on: Date("2027-01-01", strategy: Edition.dayStyle))
    }

    @Test func maintenanceWarnsAWeekBeforeExpiryWithoutChangingPublicationRules() throws {
        var catalog = CatalogFixture.make()
        let beforeNotice = try Date("2026-12-06", strategy: Edition.dayStyle)
        let notice = try Date("2026-12-07", strategy: Edition.dayStyle)
        try catalog.validatePriceFreshness(on: beforeNotice, daysNotice: 7)
        #expect(throws: CatalogError.self) { try catalog.validatePriceFreshness(on: notice, daysNotice: 7) }
        try catalog.validatePriceFreshness(on: notice)
        // A day is a UTC calendar day, independent of the build's time of day.
        let lastDay = try Date("2026-12-13T23:59:59Z", strategy: .iso8601)
        try catalog.validatePriceFreshness(on: lastDay)
        catalog.editions[0].endDate = "2026-12-06"
        try catalog.validatePriceFreshness(on: notice, daysNotice: 7)
    }

    @Test func sourceParsingDeduplicatesButPreservesConflictingPrices() throws {
        let html = """
        <div class="text-pair svelte-123"><span>RocketSim Yearly</span> <span>$69.99</span></div>
        <div class="text-pair svelte-123"><span>RocketSim Monthly</span> <span>$9.99</span></div>
        <div class="text-pair svelte-123"><span>RocketSim Yearly</span> <span>$69.99</span></div>
        <div class="text-pair svelte-123"><span>RocketSim Yearly</span> <span>$29.99</span></div>
        """
        #expect(try PriceVerification.listedPrices(in: html, plan: "RocketSim Yearly") == [Decimal(string: "29.99")!, Decimal(string: "69.99")!])
        #expect(throws: CatalogError.self) { try PriceVerification.listedPrices(in: html, plan: "Unknown") }
        #expect(throws: CatalogError.self) { try PriceVerification.listedPrices(in: html.replacingOccurrences(of: "$", with: "£"), plan: "RocketSim Yearly") }
    }

    @Test func structuredPricesMatchTheNamedUSDOfferWithoutUsingPromotionalText() throws {
        let html = #"""
        <p>Launch price $149. Team price $179.</p>
        <script type="application/ld+json">{"@graph":[
          {"@type":"Course","name":"Sample course","offers":[
            {"price":"199","priceCurrency":"USD"},
            {"price":199,"priceCurrency":"USD"},
            {"price":"99","priceCurrency":"EUR"}]},
          {"@type":"Course","name":"Other course","offers":{"price":"999","priceCurrency":"USD"}}
        ]}</script>
        """#
        #expect(try PriceVerification.structuredPrices(in: html, productName: "Sample course") == [199])
        #expect(throws: CatalogError.self) { try PriceVerification.structuredPrices(in: html, productName: "Missing course") }
        #expect(throws: CatalogError.self) { try PriceVerification.structuredPrices(in: html.replacingOccurrences(of: "USD", with: "GBP"), productName: "Sample course") }
        let conflicting = html.replacingOccurrences(of: #""price":199"#, with: #""price":249"#)
        #expect(try PriceVerification.structuredPrices(in: conflicting, productName: "Sample course") == [199, 249])
    }

    @Test(arguments: ["invalid", "199 USD", "-199", "199.999"])
    func structuredPricesRejectInvalidAmounts(price: String) throws {
        let html = "<script type=\"application/ld+json\">{\"name\":\"Sample course\",\"offers\":{\"price\":\"\(price)\",\"priceCurrency\":\"USD\"}}</script>"
        #expect(throws: CatalogError.self) { try PriceVerification.structuredPrices(in: html, productName: "Sample course") }
    }

    @Test(arguments: ["true", "false", "null", "[]", "{}"])
    func structuredPricesRejectNonPriceJSONValues(value: String) throws {
        let html = "<script type=\"application/ld+json\">{\"name\":\"Sample course\",\"offers\":{\"price\":\(value),\"priceCurrency\":\"USD\"}}</script>"
        #expect(throws: CatalogError.self) { try PriceVerification.structuredPrices(in: html, productName: "Sample course") }
    }

    @Test func structuredSourcesRequireAnExactProductName() throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].savingEstimate?.sourceFormat = .schemaOrg
        #expect(throws: CatalogError.self) { try catalog.validate() }
        catalog.offers[0].savingEstimate?.sourceProductName = "Sample course"
        try catalog.validate()
    }

    @Test @MainActor
    func manualPriceReferencesNeverReportAnAutomaticMatch() async throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].savingEstimate?.sourceFormat = .manual
        catalog.offers[0].savingEstimate?.sourceURL = "https://example.com/books"
        catalog.editions[0].valueSummary = ValueSummary(explanation: "Reviewed reference.", offerIDs: [catalog.offers[0].id])
        try catalog.validate()
        #expect(catalog.bundleValue(for: catalog.editions[0])?.totalUSD == 10)
        do {
            try await PriceVerification.verify(catalog, on: Date("2026-11-13", strategy: Edition.dayStyle))
            Issue.record("A manually reviewed source must not report an automatic match.")
        } catch {
            #expect(String(describing: error).contains("requires manual price review"))
        }
    }

    @Test(arguments: [true, false])
    @MainActor
    func liveVerificationSkipsArchivedAndUnapprovedOffers(archived: Bool) async throws {
        var catalog = CatalogFixture.make()
        if archived {
            catalog.editions[0].startDate = "2025-02-02"
            catalog.editions[0].endDate = "2025-02-04"
        } else {
            catalog.offers[0].publicationApproved = false
        }
        try catalog.validate()
        // The fixture uses a non-App-Store URL. Checking it would fail before any request.
        try await PriceVerification.verify(catalog, on: Date("2026-11-13", strategy: Edition.dayStyle))
    }
}
