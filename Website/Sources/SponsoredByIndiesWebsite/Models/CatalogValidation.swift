import Foundation

extension Catalog {
    func validate() throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw CatalogError.invalid(message) }
        }
        func unique(_ values: [String], _ label: String) throws {
            try require(Set(values).count == values.count, "Duplicate \(label).")
        }
        func slug(_ value: String) -> Bool {
            value.range(of: "^[a-z0-9]+(?:-[a-z0-9]+)*$", options: .regularExpression) != nil
        }
        func nonempty(_ values: [String], _ context: String) throws {
            try require(values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                        "Blank required content in \(context).")
        }
        func validDate(_ value: String) -> Bool {
            let parsed = try? Date(value, strategy: Edition.dayStyle)
            return parsed.map { $0.formatted(Edition.dayStyle) == value } == true
        }
        try require(validDate(terms.updatedOn), "Terms update date must be YYYY-MM-DD.")
        try nonempty([terms.introduction], "terms introduction")
        try require(!terms.sections.isEmpty, "Terms need at least one section.")
        for section in terms.sections {
            try nonempty([section.heading] + section.paragraphs, "terms section")
            try require(!section.paragraphs.isEmpty, "Terms sections need explanatory text.")
        }
        try unique(conferences.map(\.id), "conference ID")
        try unique(conferences.map(\.slug), "conference route")
        try unique(editions.map(\.id), "edition ID")
        try unique(indies.map(\.id), "indie ID")
        try unique(offers.map(\.id), "offer ID")
        try unique(editions.map { "\($0.conferenceID)/\($0.slug)" }, "edition route")
        try unique(participations.map { "\($0.editionID)/\($0.indieID)" }, "participation")
        for conference in conferences {
            try nonempty([conference.id, conference.name, conference.location, conference.description], conference.id)
            if let editions = conference.connectionEditions {
                try nonempty(editions, "connection editions for \(conference.id)")
                try unique(editions, "connection edition for \(conference.id)")
            }
            try require(slug(conference.slug), "Invalid conference slug: \(conference.slug)")
            try Self.validateURL(conference.websiteURL)
            if let branding = conference.branding {
                try require(branding.colors.allSatisfy {
                    $0.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil
                }, "Conference \(conference.id) colours must be six-digit hex values.")
            }
        }
        for edition in editions {
            try nonempty([edition.id, edition.label, edition.dateLabel, edition.status,
                          edition.introduction, edition.accessIntroduction], edition.id)
            try require(slug(edition.slug), "Invalid edition slug: \(edition.slug)")
            try require(conferences.contains { $0.id == edition.conferenceID }, "Unknown conference for \(edition.id)")
            for value in [edition.startDate, edition.endDate] {
                try require(validDate(value),
                            "Edition \(edition.id) needs valid YYYY-MM-DD dates.")
            }
            try require(edition.startDate <= edition.endDate, "Edition \(edition.id) ends before it starts.")
            if let url = edition.accessURL { try Self.validateURL(url) }
            if let note = edition.bundleNote { try nonempty([note], "bundle note for \(edition.id)") }
            if let value = edition.valueSummary {
                let approved = Set(visibleOffers(for: edition).map(\.id))
                try require(!value.offerIDs.isEmpty && Set(value.offerIDs).isSubset(of: approved),
                            "Value summary must reference approved offers for \(edition.id)")
                try require(validDate(value.verifiedOn), "Value verification date must be YYYY-MM-DD.")
                try unique(value.offerIDs, "value summary offer ID")
                try nonempty([value.amountLabel, value.explanation], "value summary for \(edition.id)")
            }
        }
        for indie in indies {
            try nonempty([indie.id, indie.name, indie.initials], "indie \(indie.id)")
            if let url = indie.websiteURL { try Self.validateURL(url) }
            for link in indie.socials {
                try nonempty([link.label], "social link for \(indie.id)")
                try Self.validateURL(link.url)
            }
        }
        for participation in participations {
            try require(editions.contains { $0.id == participation.editionID }, "Unknown participation edition")
            try require(indies.contains { $0.id == participation.indieID }, "Unknown participation indie")
            if participation.quote != nil {
                try require(participation.publicationApproved, "Quotes require publication approval.")
            }
        }
        for offer in offers {
            try require(participations.contains {
                $0.editionID == offer.editionID && $0.indieID == offer.indieID
            }, "Offer \(offer.id) has no participation in its edition.")
            try Self.validateURL(offer.productURL)
            if let estimate = offer.savingEstimate {
                try require(estimate.amountUSD.isFinite && estimate.amountUSD >= 0,
                            "Savings must be finite, non-negative USD amounts.")
                try require(validDate(estimate.verifiedOn), "Savings verification date must be YYYY-MM-DD.")
                try Self.validateURL(estimate.sourceURL)
            }
            if let path = offer.productIconPath {
                try require(path.range(of: "^/app-icons/[a-z0-9-]+\\.png$", options: .regularExpression) != nil,
                            "Product icons must use a local PNG in /app-icons/.")
            }
            if offer.publicationApproved {
                try nonempty([offer.productName, offer.description, offer.benefit,
                              offer.terms, offer.redemptionInstructions], "approved offer \(offer.id)")
                try require(participations.contains {
                    $0.editionID == offer.editionID && $0.indieID == offer.indieID && $0.publicationApproved
                }, "Approved offer \(offer.id) needs approved participation in its edition.")
            }
        }
        if let contactURL { try Self.validateURL(contactURL, allowMail: true) }
    }

    private static func validateURL(_ string: String, allowMail: Bool = false) throws {
        guard !string.contains(where: { $0.isWhitespace || $0.isNewline }),
              let url = URLComponents(string: string),
              url.user == nil, url.password == nil,
              (url.scheme == "https" && !(url.host ?? "").isEmpty) ||
                (allowMail && url.scheme == "mailto" && url.path.contains("@") &&
                 !url.path.contains(where: { $0.isWhitespace || $0.isNewline }) &&
                 url.query == nil && url.fragment == nil) else {
            throw CatalogError.invalid("Expected a valid HTTPS URL: \(string)")
        }
    }
}
