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
    var bundleNote: String? = nil

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
    var isEstimate: Bool = false
}

extension ValueSummary {
    private enum CodingKeys: String, CodingKey {
        case amountLabel, explanation, verifiedOn, offerIDs, isEstimate
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        amountLabel = try values.decode(String.self, forKey: .amountLabel)
        explanation = try values.decode(String.self, forKey: .explanation)
        verifiedOn = try values.decode(String.self, forKey: .verifiedOn)
        offerIDs = try values.decode([String].self, forKey: .offerIDs)
        // Existing records predate the estimate flag and retain their original label.
        isEstimate = try values.decodeIfPresent(Bool.self, forKey: .isEstimate) ?? false
    }
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
    var productIconPath: String? = nil
    var savingEstimate: SavingEstimate? = nil
    var description: String
    var benefit: String
    var terms: String
    var redemptionInstructions: String
    var publicationApproved: Bool
}

/// Compare every contribution against US App Store prices in USD, regardless
/// of the conference location. Estimates record their public price reference.
struct SavingEstimate: Decodable {
    var amountUSD: Double
    var verifiedOn: String
    var sourceURL: String
}

struct ProductContribution {
    var product: Offer
    var offers: [Offer]
    var maximumSavingUSD: Double? { offers.compactMap { $0.savingEstimate?.amountUSD }.max() }
}

enum CatalogError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): message }
    }
}
