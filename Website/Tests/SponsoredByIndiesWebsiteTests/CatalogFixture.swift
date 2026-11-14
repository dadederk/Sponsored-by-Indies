import Foundation

@testable import SponsoredByIndiesWebsite

/// Synthetic public content shared by tests; never loaded into the real site.
enum CatalogFixture {
    static func showcase() -> Catalog {
        var catalog = make()
        let offer = catalog.offers[0]
        catalog.projects = [Project(id: "tool", indieID: offer.indieID, name: offer.productName,
                                    websiteURL: offer.productURL, iconPath: offer.productIconPath,
                                    description: offer.description, showcaseDescription: "A longer project story & <details>.")]
        catalog.offers[0].projectID = "tool"
        return catalog
    }

    static func make() -> Catalog {
        let conference = Conference(
            id: "sample", slug: "sample", name: "Sample Conference", location: "Sample City",
            websiteURL: "https://example.org", description: "A conference for independent makers.",
            branding: ConferenceBranding(
                background: "#183d35", accent: "#d7e5b3",
                highlight: "#d7e5b3", detail: "#ffffff")
        )
        let edition = Edition(
            id: "sample-2027", conferenceID: conference.id, slug: "2027", label: "2027",
            dateLabel: "2–4 February 2027", startDate: "2027-02-02", endDate: "2027-02-04",
            introduction: "Independent products for attendees.",
            accessIntroduction: "Use the conference attendee portal.", accessURL: "https://example.org/attendees",
            valueSummary: nil
        )
        let indie = Indie(
            id: "maker", name: "A & B <Studio>", company: "Sample Company",
            websiteURL: "https://example.org/maker",
            socials: [SocialLink(label: "Maker social", url: "https://example.org/social")], initials: "AB")
        let participation = Participation(
            editionID: edition.id, indieID: indie.id,
            connection: "A returning speaker.", quote: "A welcoming community.",
            publicationApproved: true)
        var offer = Offer(
            id: "tool", editionID: edition.id, indieID: indie.id, productName: "Tool & <Kit>",
            productURL: "https://example.org/tool", description: "An indie tool.", benefit: "Free access.",
            terms: "For ticket holders.", redemptionInstructions: "Follow the attendee instructions.",
            publicationApproved: true
        )
        offer.savingEstimate = saving()
        return Catalog(
            conferences: [conference], editions: [edition], indies: [indie],
            participations: [participation], offers: [offer], contactURL: "mailto:hello@example.org",
            partnershipNote: nil,
            terms: CommunityTerms(updatedOn: "2026-11-12", introduction: "Community & <care>.",
                                  sections: [.init(heading: "Shared <responsibilities>", paragraphs: ["A & B act independently."])]))
    }
    static func saving(price: Decimal = 10, percent: Int = 100, plan: String = "Sample plan") -> SavingEstimate {
        SavingEstimate(regularPriceUSD: price, discountPercent: percent, plan: plan,
                       period: .year, discountedPeriods: 1, currency: "USD", storefront: "US",
                       observedPricesUSD: [price], review: .unambiguous,
                       verifiedOn: "2026-11-13", sourceURL: "https://example.org/price")
    }

}
