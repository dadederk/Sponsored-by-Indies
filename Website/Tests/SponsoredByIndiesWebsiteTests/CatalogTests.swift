import Foundation
import Testing

@testable import SponsoredByIndiesWebsite

struct CatalogTests {
    private var directory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Data")
    }

    @Test func curatedContentLoads() throws {
        let catalog = try Catalog.load(from: directory)
        #expect(!catalog.conferences.isEmpty)
        try catalog.validate()
    }

    @Test(arguments: ["date", "introduction", "sections", "heading", "paragraphs", "blank paragraph"])
    func rejectsIncompleteTerms(field: String) throws {
        var catalog = CatalogFixture.make()
        switch field {
        case "date": catalog.terms.updatedOn = "2026-02-30"
        case "introduction": catalog.terms.introduction = "  "
        case "sections": catalog.terms.sections = []
        case "heading": catalog.terms.sections[0].heading = "\n"
        case "paragraphs": catalog.terms.sections[0].paragraphs = []
        default: catalog.terms.sections[0].paragraphs = ["   "]
        }
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func approvalDoesNotCarryBetweenEditions() throws {
        var catalog = CatalogFixture.make()
        var second = try #require(catalog.editions.first)
        second.id = "sample-2028"
        second.slug = "2028"
        catalog.editions.append(second)
        catalog.participations.append(
            Participation(
                editionID: second.id, indieID: "maker",
                connection: nil, quote: nil, publicationApproved: false))
        try catalog.validate()
        #expect(catalog.visibleParticipations(for: second).isEmpty)
        #expect(catalog.visibleOffers(for: second).isEmpty)
        #expect(catalog.visibleOffers(for: catalog.editions[0]).count == 1)
        catalog.participations[0].quote = nil
        catalog.participations[0].publicationApproved = false
        #expect(catalog.visibleOffers(for: catalog.editions[0]).isEmpty)
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test(arguments: [[""], ["  "], ["2024", "2024"]])
    func rejectsInvalidConnectionEditions(labels: [String]) throws {
        var catalog = CatalogFixture.make()
        catalog.conferences[0].connectionEditions = labels
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func rejectsBlankApprovedTerms(value: String) throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].terms = value
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func rejectsBrokenReferencesAndDuplicateRoutes() throws {
        var catalog = CatalogFixture.make()
        catalog.editions[0].conferenceID = "missing"
        #expect(throws: CatalogError.self) { try catalog.validate() }
        catalog = CatalogFixture.make()
        catalog.conferences.append(catalog.conferences[0])
        #expect(throws: CatalogError.self) { try catalog.validate() }
        catalog = CatalogFixture.make()
        catalog.participations[0].indieID = "missing"
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test(arguments: ["2027-02-30", "2027-2-02", "yesterday"])
    func rejectsInvalidDates(value: String) throws {
        var catalog = CatalogFixture.make()
        catalog.editions[0].startDate = value
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func valueRequiresApprovedCompatibleOffersAndVerification() throws {
        var catalog = CatalogFixture.make()
        catalog.editions[0].valueSummary = ValueSummary(
            explanation: "One compatible saving.", offerIDs: ["tool"])
        try catalog.validate()
        catalog.editions[0].valueSummary?.offerIDs = ["unknown"]
        #expect(throws: CatalogError.self) { try catalog.validate() }
        catalog.editions[0].valueSummary?.offerIDs = ["tool"]
        catalog.offers[0].savingEstimate?.verifiedOn = "not a date"
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test(arguments: ["javascript:alert(1)", "https:///", "https://user:password@example.org", "https://example.org/a b"])
    func rejectsUnsafeURLs(value: String) throws {
        var catalog = CatalogFixture.make()
        catalog.conferences[0].websiteURL = value
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test(arguments: ["https://example.org/icon.png", "/app-icons/../secret.png", "/app-icons/a\".png"])
    func rejectsUnsafeIconPaths(path: String) throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].productIconPath = path
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func rejectsCSSInBranding() throws {
        var catalog = CatalogFixture.make()
        catalog.conferences[0].branding?.accent = "red; display:none"
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func selectsByDateRatherThanSlugAndIncludesFinalDay() throws {
        var catalog = CatalogFixture.make()
        var later = catalog.editions[0]
        later.id = "sample-later"
        later.slug = "a-later-edition"
        later.startDate = "2027-05-01"
        later.endDate = "2027-05-02"
        catalog.editions.append(later)
        let conference = catalog.conferences[0]
        let finalDay = try Date("2027-02-04", strategy: Edition.dayStyle)
        #expect(catalog.nextEdition(on: finalDay)?.id == "sample-2027")
        #expect(catalog.featuredEdition(for: conference, on: finalDay)?.id == "sample-2027")
        let nextDay = try Date("2027-02-05", strategy: Edition.dayStyle)
        #expect(catalog.nextEdition(on: nextDay)?.id == later.id)
        let past = try Date("2028-01-01", strategy: Edition.dayStyle)
        #expect(catalog.nextEdition(on: past) == nil)
        #expect(catalog.featuredEdition(for: conference, on: past)?.id == later.id)
        #expect(catalog.editions(for: conference).first?.id == later.id)
    }

    @Test func multipleConferencesKeepTheirOwnContributions() throws {
        var catalog = CatalogFixture.make()
        var conference = catalog.conferences[0]
        conference.id = "another"
        conference.slug = "another"
        conference.branding = nil
        catalog.conferences.append(conference)
        var edition = catalog.editions[0]
        edition.id = "another-2027"
        edition.conferenceID = conference.id
        catalog.editions.append(edition)
        try catalog.validate()
        #expect(edition.path(in: catalog) == "/conferences/another/2027/")
        #expect(catalog.visibleOffers(for: edition).isEmpty)
        #expect(catalog.visibleParticipations(for: edition).isEmpty)
        #expect(catalog.editions(for: conference).count == 1)
        #expect(conference.identityStyle.isEmpty)
    }

    @Test func sameDayChoiceUsesStableUnicodeOrdering() throws {
        let today = try Date("2027-02-01", strategy: Edition.dayStyle)
        for (expected, other) in [("B", "a"), ("z", "é"), ("z", "e\u{0301}"), ("\u{E000}", "😀")] {
            for ids in [[other, expected], [expected, other]] {
                var catalog = CatalogFixture.make()
                let template = catalog.editions[0]
                catalog.editions = ids.enumerated().map { index, id in
                    var edition = template
                    edition.id = id
                    edition.slug = String(index)
                    return edition
                }
                catalog.offers = []
                catalog.participations = []
                try catalog.validate()
                #expect(catalog.nextEdition(on: today)?.id == expected)
                #expect(catalog.featuredEdition(for: catalog.conferences[0], on: today)?.id == expected)
            }
        }
    }

    @Test func productsRankByMaximumSavingRatherThanSumOrSubmissionOrder() throws {
        var catalog = CatalogFixture.make()
        let original = catalog.offers[0]
        func offer(_ id: String, product: String, saving: Decimal?) -> Offer {
            var result = original
            result.id = id
            result.productName = product
            result.productURL = "https://example.org/" + product.lowercased()
            result.savingEstimate = saving.map {
                CatalogFixture.saving(price: $0)
            }
            return result
        }
        catalog.offers = [
            offer("unknown", product: "Unknown", saving: nil),
            offer("b-one", product: "Beta", saving: 8),
            offer("b-two", product: "Beta", saving: 9),
            offer("z", product: "Zulu", saving: 10),
            offer("a", product: "Alpha", saving: 10)
        ]
        var draft = offer("draft", product: "Draft", saving: 1000)
        draft.publicationApproved = false
        catalog.offers.append(draft)
        try catalog.validate()
        for offers in [catalog.offers, catalog.offers.reversed().map { $0 }] {
            catalog.offers = offers
            let products = catalog.visibleProductContributions(for: catalog.editions[0])
            #expect(products.map(\.product.productName) == ["Alpha", "Zulu", "Beta", "Unknown"])
            #expect(products[2].offers.count == 2)
            #expect(products[2].maximumSavingUSD == 9)
        }
    }

    @Test(arguments: [Decimal(-1), Decimal.nan, Decimal(string: "10.001")!])
    func rejectsInvalidSavings(amount: Decimal) throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].savingEstimate = CatalogFixture.saving(price: amount)
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func savingEstimatesNeedValidEvidence() throws {
        var catalog = CatalogFixture.make()
        catalog.offers[0].savingEstimate?.verifiedOn = "2026-02-30"
        #expect(throws: CatalogError.self) { try catalog.validate() }
        catalog.offers[0].savingEstimate?.verifiedOn = "2026-11-13"
        catalog.offers[0].savingEstimate?.sourceURL = "javascript:alert(1)"
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func missingContentFailsInsteadOfPublishingEmptyPages() throws {
        #expect(throws: (any Error).self) {
            try Catalog.load(from: directory.appendingPathComponent("missing"))
        }
    }
}
