import Foundation
import Testing

@testable import SponsoredByIndiesWebsite

struct SavingsTests {
    @Test(arguments: [("69.99", 30, "20.99"), ("29.99", 50, "14.99"), ("29.99", 100, "29.99"), ("0.01", 30, "0")])
    func savingsUseDecimalArithmeticAndConservativeCents(price: String, percent: Int, saving: String) throws {
        let evidence = CatalogFixture.saving(price: try #require(Decimal(string: price)), percent: percent)
        #expect(evidence.amountUSD == Decimal(string: saving))
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
        #expect(products.map(\.product.productName) == ["AI Fundamentals", "Dee: Muay Thai Coach", "RocketSim for Xcode", "RocketTrace for Xcode", "Xarra!", "RetroRapid!"])
        let value = try #require(catalog.bundleValue(for: edition))
        #expect(value.totalUSD == products.reduce(0) { $0 + ($1.maximumSavingUSD ?? 0) })
        #expect(value.totalUSD == Decimal(string: "139.70"))
        #expect(value.amountLabel == "US$139")
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

    @Test func structuredSourcesRequireAnExactProductName() throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].savingEstimate?.sourceFormat = .schemaOrg
        #expect(throws: CatalogError.self) { try catalog.validate() }
        catalog.offers[0].savingEstimate?.sourceProductName = "Sample course"
        try catalog.validate()
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
