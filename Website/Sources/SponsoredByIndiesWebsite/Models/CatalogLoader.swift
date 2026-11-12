import Foundation

extension Catalog {
    /// Read only curated public content. Internal outreach trackers are never inputs.
    static func load(from directory: URL) throws -> Catalog {
        func decode<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
            do {
                return try JSONDecoder().decode(type, from: Data(contentsOf: url))
            } catch {
                throw CatalogError.invalid("Unable to load \(url.path): \(error)")
            }
        }

        let settings = try decode(Settings.self, at: directory.appendingPathComponent("site.json"))
        let indies = try decode([Indie].self, at: directory.appendingPathComponent("indies.json"))
        let files = try FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent("Conferences"), includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let records = try files.map { try decode(ConferenceRecord.self, at: $0) }
        for record in records {
            guard record.editions.allSatisfy({ $0.conferenceID == record.conference.id }) else {
                throw CatalogError.invalid("Editions in \(record.conference.id) must belong to that conference.")
            }
            let editionIDs = Set(record.editions.map(\.id))
            guard record.participations.allSatisfy({ editionIDs.contains($0.editionID) }),
                  record.offers.allSatisfy({ editionIDs.contains($0.editionID) }) else {
                throw CatalogError.invalid("Contributions in \(record.conference.id) must belong to its editions.")
            }
        }
        let catalog = Catalog(
            conferences: records.map(\.conference), editions: records.flatMap(\.editions),
            indies: indies, participations: records.flatMap(\.participations),
            offers: records.flatMap(\.offers), contactURL: settings.contactURL,
            partnershipNote: settings.partnershipNote, terms: settings.terms
        )
        try catalog.validate()
        return catalog
    }
}

private struct Settings: Decodable {
    let contactURL: String?
    let partnershipNote: String?
    let terms: CommunityTerms
}

private struct ConferenceRecord: Decodable {
    let conference: Conference
    let editions: [Edition]
    let participations: [Participation]
    let offers: [Offer]
}
