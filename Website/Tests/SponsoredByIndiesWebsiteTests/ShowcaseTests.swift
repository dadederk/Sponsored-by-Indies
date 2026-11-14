import Foundation
import Testing
@testable import SponsoredByIndiesWebsite

struct ShowcaseTests {
    @Test func builderLinksKeepTheRequestedOrderWithOptionalProfiles() {
        var person = IndiePerson(name: "A builder", websiteURL: "https://example.org", socials: [
            SocialLink(label: "GitHub", url: "https://github.com/example"),
            SocialLink(label: "Twitter", url: "https://x.com/example"),
            SocialLink(label: "Bluesky", url: "https://bsky.app/profile/example.org"),
            SocialLink(label: "Mastodon", url: "https://example.social/@builder")
        ])
        #expect(person.showcaseLinks.map(\.label) == ["Website", "Mastodon", "Bluesky", "Twitter", "GitHub"])
        person.websiteURL = nil
        person.socials?.removeAll { $0.label == "Bluesky" }
        #expect(person.showcaseLinks.map(\.label) == ["Mastodon", "Twitter", "GitHub"])
        person.socials = nil
        #expect(person.showcaseLinks.isEmpty)
    }

    @Test func showcaseDeduplicatesAlternativesAndEditionsAndKeepsHistoricalContributors() throws {
        var catalog = CatalogFixture.showcase()
        var alternative = catalog.offers[0]
        alternative.id = "alternative"
        catalog.offers.append(alternative)
        var archived = catalog.editions[0]
        archived.id = "sample-2000"
        archived.slug = "2000"
        archived.startDate = "2000-01-01"
        archived.endDate = "2000-01-02"
        catalog.editions.append(archived)
        var participation = catalog.participations[0]
        participation.editionID = archived.id
        catalog.participations.append(participation)
        var historical = catalog.offers[0]
        historical.id = "historical"
        historical.editionID = archived.id
        catalog.offers.append(historical)
        var unlisted = catalog.projects[0]
        unlisted.id = "unlisted"
        unlisted.websiteURL = "https://example.org/unlisted"
        catalog.projects.append(unlisted)
        try catalog.validate()
        #expect(catalog.showcaseProjects.map(\.id) == ["tool"])
        #expect(catalog.contributingEditions(for: catalog.projects[0]).map(\.id) == ["sample-2000", "sample-2027"])
        catalog.offers[0].publicationApproved = false
        catalog.offers[1].publicationApproved = false
        #expect(catalog.showcaseProjects.count == 1)
        catalog.participations[1].publicationApproved = false
        #expect(catalog.showcaseProjects.isEmpty)
    }

    @Test func showcaseOrdersByProjectNameRatherThanSaving() throws {
        var catalog = CatalogFixture.showcase()
        var project = catalog.projects[0]
        project.id = "alpha"
        project.name = "Alpha"
        project.websiteURL = "https://example.org/alpha"
        catalog.projects.append(project)
        var offer = catalog.offers[0]
        offer.id = "alpha"
        offer.projectID = project.id
        offer.productName = project.name
        offer.productURL = project.websiteURL
        offer.savingEstimate = nil
        catalog.offers.append(offer)
        try catalog.validate()
        #expect(catalog.showcaseProjects.map(\.id) == ["alpha", "tool"])
    }

    @Test(arguments: ["duplicate", "unknown-maker", "invalid-id", "unsafe-url", "empty-description", "mismatched-offer", "unsafe-portrait", "unsafe-social"])
    func rejectsInvalidProjectAndProfileContent(problem: String) {
        var catalog = CatalogFixture.showcase()
        catalog.indies[0].people = [IndiePerson(name: "A builder", websiteURL: nil)]
        switch problem {
        case "duplicate": catalog.projects.append(catalog.projects[0])
        case "unknown-maker": catalog.projects[0].indieID = "missing"
        case "invalid-id": catalog.projects[0].id = "bad/#anchor"
        case "unsafe-url": catalog.projects[0].websiteURL = "javascript:alert(1)"
        case "empty-description": catalog.projects[0].showcaseDescription = " "
        case "mismatched-offer": catalog.offers[0].projectID = "missing"
        case "unsafe-portrait": catalog.indies[0].people?[0].portraitPath = "/portraits/../../private.png"
        default: catalog.indies[0].people?[0].socials = [SocialLink(label: "Social", url: "javascript:alert(1)")]
        }
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test func loaderRejectsUnknownProjectsAndMissingLocalPortraits() throws {
        let files = FileManager.default
        let website = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = files.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? files.removeItem(at: root) }
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        try files.copyItem(at: website.appending(path: "Data"), to: root.appending(path: "Data"))
        try files.copyItem(at: website.appending(path: "Assets"), to: root.appending(path: "Assets"))
        #expect(try Catalog.load(from: root.appending(path: "Data")).showcaseProjects.count == 6)
        let conference = root.appending(path: "Data/Conferences/arctic.json")
        let source = try String(contentsOf: conference, encoding: .utf8)
        try source.replacingOccurrences(of: "\"projectID\": \"xarra\"", with: "\"projectID\": \"missing\"")
            .write(to: conference, atomically: true, encoding: .utf8)
        #expect(throws: CatalogError.self) { try Catalog.load(from: root.appending(path: "Data")) }
        try source.write(to: conference, atomically: true, encoding: .utf8)
        try files.removeItem(at: root.appending(path: "Assets/portraits/dani-devesa.jpg"))
        #expect(throws: CatalogError.self) { try Catalog.load(from: root.appending(path: "Data")) }
    }
}
