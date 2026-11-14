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
    var introduction: String
    var accessIntroduction: String
    var accessURL: String?
    var valueSummary: ValueSummary?
    var bundleNote: String? = nil

    // Date-only scheduling uses UTC consistently in the build and browser.
    static var dayStyle: Date.ISO8601FormatStyle {
        .iso8601.year().month().day().dateSeparator(.dash)
    }

    func path(in catalog: Catalog) -> String { catalog.conference(for: self).path + slug + "/" }
}

/// Explicitly reviewed compatible offers; monetary amounts are computed from evidence.
struct ValueSummary: Decodable {
    var explanation: String
    var offerIDs: [String]
}

struct Indie: Decodable {
    var id: String
    var name: String
    var company: String?
    var websiteURL: String?
    var socials: [SocialLink]
    var initials: String
    var people: [IndiePerson]? = nil
}

struct IndiePerson: Decodable {
    var name: String
    var websiteURL: String?
    var bio: String? = nil
    var portraitPath: String? = nil
    var socials: [SocialLink]? = nil

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var showcaseLinks: [SocialLink] {
        let order = ["Mastodon": 0, "Bluesky": 1, "Twitter": 2, "GitHub": 3]
        let profiles = (socials ?? []).sorted {
            (order[$0.label] ?? 4, $0.label, $0.url) < (order[$1.label] ?? 4, $1.label, $1.url)
        }
        return (websiteURL.map { [SocialLink(label: "Website", url: $0)] } ?? []) + profiles
    }
}

struct Project: Decodable {
    var id: String
    var indieID: String
    var name: String
    var websiteURL: String
    var iconPath: String?
    var description: String
    var showcaseDescription: String

    var bundleAnchor: String { "project-" + id }
}

struct SocialLink: Decodable {
    var label: String
    var url: String
}

struct DiscoveryResource: Decodable {
    var name: String
    var url: String
    var description: String
}

struct Participation: Decodable {
    var editionID: String
    var indieID: String
    var connection: String?
    var quote: String?
    var publicationApproved: Bool
    var quoteAttribution: QuoteAttribution? = nil
}

struct QuoteAttribution: Decodable {
    var name: String
    var sourceURL: String
}

/// Resolved snapshot for rendering. Editorial product details live in projects.json.
struct Offer {
    var id: String
    var editionID: String
    var indieID: String
    var productName: String
    var productURL: String
    var productIconPath: String? = nil
    var savingEstimate: SavingEstimate? = nil
    var description: String
    var benefit: String
    var terms: String
    var redemptionInstructions: String
    var publicationApproved: Bool
    var projectID: String? = nil

    var bundleAnchor: String {
        projectID.map { "project-" + $0 } ?? "offer-" + id.utf8.map { String($0, radix: 16) }.joined(separator: "-")
    }
}

struct ProductContribution {
    var product: Offer
    var offers: [Offer]
    var maximumSavingUSD: Decimal? { offers.compactMap { $0.savingEstimate?.amountUSD }.max() }
}

enum CatalogError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): message }
    }
}
