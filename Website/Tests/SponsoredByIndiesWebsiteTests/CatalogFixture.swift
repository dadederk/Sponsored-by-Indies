import Foundation

@testable import SponsoredByIndiesWebsite

/// Synthetic public content shared by tests; never loaded into the real site.
enum CatalogFixture {
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
            status: "Confirmed", introduction: "Independent products for attendees.",
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
        let offer = Offer(
            id: "tool", editionID: edition.id, indieID: indie.id, productName: "Tool & <Kit>",
            productURL: "https://example.org/tool", description: "An indie tool.", benefit: "Free access.",
            terms: "For ticket holders.", redemptionInstructions: "Follow the attendee instructions.",
            publicationApproved: true
        )
        return Catalog(
            conferences: [conference], editions: [edition], indies: [indie],
            participations: [participation], offers: [offer], contactURL: "mailto:hello@example.org",
            partnershipNote: nil,
            terms: CommunityTerms(updatedOn: "2026-11-12", introduction: "Community & <care>.",
                                  sections: [.init(heading: "Shared <responsibilities>", paragraphs: ["A & B act independently."])]))
    }
}
