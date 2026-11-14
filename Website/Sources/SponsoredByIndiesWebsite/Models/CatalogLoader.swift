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
        let projects = try decode([Project].self, at: directory.appendingPathComponent("projects.json"))
        let files = try FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent("Conferences"), includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let records = try files.map { try decode(ConferenceRecord.self, at: $0) }
        // Check identities before constructing a lookup or resolving offer records.
        try validateProjects(projects, indies: indies)
        let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
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
            offers: try records.flatMap(\.offers).map { try $0.resolve(in: projectsByID) }, contactURL: settings.contactURL,
            partnershipNote: settings.partnershipNote, terms: settings.terms, projects: projects,
            discoveryResources: settings.discoveryResources ?? []
        )
        try catalog.validate()
        let images = projects.compactMap(\.iconPath) + indies.flatMap { ($0.people ?? []).compactMap(\.portraitPath) }
        for path in images {
            let file = directory.deletingLastPathComponent().appending(path: "Assets" + path)
            guard FileManager.default.fileExists(atPath: file.path) else {
                throw CatalogError.invalid("Missing local image: \(path).")
            }
        }
        return catalog
    }
}

private struct Settings: Decodable {
    let contactURL: String?
    let partnershipNote: String?
    let terms: CommunityTerms
    let discoveryResources: [DiscoveryResource]?
}

private struct ConferenceRecord: Decodable {
    let conference: Conference
    let editions: [Edition]
    let participations: [Participation]
    let offers: [OfferRecord]
}

private struct OfferRecord: Decodable {
    let id: String
    let editionID: String
    let projectID: String
    let savingEstimate: SavingEstimate?
    let benefit: String
    let terms: String
    let redemptionInstructions: String
    let publicationApproved: Bool

    func resolve(in projects: [String: Project]) throws -> Offer {
        guard let project = projects[projectID] else {
            throw CatalogError.invalid("Unknown project \(projectID) for offer \(id).")
        }
        return Offer(
            id: id, editionID: editionID, indieID: project.indieID,
            productName: project.name, productURL: project.websiteURL, productIconPath: project.iconPath,
            savingEstimate: savingEstimate, description: project.description, benefit: benefit,
            terms: terms, redemptionInstructions: redemptionInstructions,
            publicationApproved: publicationApproved, projectID: project.id)
    }
}
