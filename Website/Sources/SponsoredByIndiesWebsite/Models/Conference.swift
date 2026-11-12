import Foundation


struct Conference: Decodable {
    var id: String
    var slug: String
    var name: String
    var location: String
    var websiteURL: String
    var description: String
    var branding: ConferenceBranding?
    var connectionEditions: [String]? = nil
    var path: String { "/conferences/\(slug)/" }

    // Custom properties let one shared stylesheet style every conference. Ignite
    // Custom properties use validated values to inherit conference colours.
    var identityStyle: String { branding?.cssProperties ?? "" }
}

struct ConferenceBranding: Decodable {
    var background: String
    var accent: String
    var highlight: String
    var detail: String

    var colors: [String] { [background, accent, highlight, detail] }
    var cssProperties: String {
        "--conference-bg: \(background); --conference-accent: \(accent); --conference-highlight: \(highlight); --conference-detail: \(detail)"
    }
}

struct Edition: Decodable {
    var id: String
    var conferenceID: String
    var slug: String
    var label: String
    var dateLabel: String
    var startDate: String
    var endDate: String
    var status: String
    var introduction: String
    var accessIntroduction: String
    var accessURL: String?
    var valueSummary: ValueSummary?

    // Date-only scheduling uses UTC consistently in the build and browser.
    static var dayStyle: Date.ISO8601FormatStyle {
        .iso8601.year().month().day().dateSeparator(.dash)
    }

    func path(in catalog: Catalog) -> String { catalog.conference(for: self).path + slug + "/" }
}

/// This is an editorially verified compatible total, not a sum of advertised discounts.
struct ValueSummary: Decodable {
    var amountLabel: String
    var explanation: String
    var verifiedOn: String
    var offerIDs: [String]
}

struct Indie: Decodable {
    var id: String
    var name: String
    var company: String?
    var websiteURL: String?
    var socials: [SocialLink]
    var initials: String
}

struct SocialLink: Decodable {
    var label: String
    var url: String
}

struct Participation: Decodable {
    var editionID: String
    var indieID: String
    var connection: String?
    var quote: String?
    var publicationApproved: Bool
}

struct Offer: Decodable {
    var id: String
    var editionID: String
    var indieID: String
    var productName: String
    var productURL: String
    var description: String
    var benefit: String
    var terms: String
    var redemptionInstructions: String
    var publicationApproved: Bool
}

enum CatalogError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): message }
    }
}
