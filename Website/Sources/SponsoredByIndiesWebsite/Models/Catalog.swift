import Foundation

/// Validate once at the loading boundary, before resolving references or rendering.
struct Catalog: Decodable {
    var conferences: [Conference]
    var editions: [Edition]
    var indies: [Indie]
    var participations: [Participation]
    var offers: [Offer]
    var contactURL: String?
    var partnershipNote: String?
    var terms: CommunityTerms

    func conference(for edition: Edition) -> Conference {
        guard let conference = conferences.first(where: { $0.id == edition.conferenceID }) else {
            preconditionFailure("Validate the catalogue before rendering: unknown conference for \(edition.id).")
        }
        return conference
    }

    func indie(withID id: String) -> Indie {
        guard let indie = indies.first(where: { $0.id == id }) else {
            preconditionFailure("Validate the catalogue before rendering: unknown indie \(id).")
        }
        return indie
    }

    func editions(for conference: Conference) -> [Edition] {
        editions.filter { $0.conferenceID == conference.id }
            .sorted { ($0.startDate, $0.id) > ($1.startDate, $1.id) }
    }

    /// Prefer the next/current edition; retain the newest past one for an archive.
    func featuredEdition(for conference: Conference, on date: Date = .now) -> Edition? {
        let editions = editions(for: conference)
        let today = date.formatted(Edition.dayStyle)
        return editions.reversed().first { $0.endDate >= today } ?? editions.first
    }

    var editionsByDate: [Edition] {
        editions.sorted { ($0.startDate, $0.id) < ($1.startDate, $1.id) }
    }

    func nextEdition(on date: Date = .now) -> Edition? {
        let today = date.formatted(Edition.dayStyle)
        return editionsByDate.first { $0.endDate >= today }
    }

    func visibleParticipations(for edition: Edition) -> [Participation] {
        participations.filter { $0.editionID == edition.id && $0.publicationApproved }
    }

    func visibleOffers(for edition: Edition) -> [Offer] {
        offers.filter { offer in
            offer.editionID == edition.id && offer.publicationApproved &&
            participations.contains {
                $0.editionID == edition.id && $0.indieID == offer.indieID && $0.publicationApproved
            }
        }
    }

}
