import Foundation
import Ignite
import Testing

@testable import SponsoredByIndiesWebsite

extension PublishingTests {
    @Test(arguments: [true, false])
    func conferenceDescriptionsLinkEscapedTextAndKeepMetadataPlain(hasEdition: Bool) async throws {
        var catalog = CatalogFixture.make()
        catalog.conferences[0].description = "A & <friendly> conference at Venue & <Hall>."
        catalog.conferences[0].descriptionLink = .init(
            text: "Venue & <Hall>", url: "https://example.org/venue?a=1&b=2")
        if !hasEdition {
            catalog.editions = []
            catalog.participations = []
            catalog.offers = []
        }
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let route = hasEdition ? "conferences/sample/2027/index.html" : "conferences/sample/index.html"
        let html = try String(contentsOf: root.appending(path: route), encoding: .utf8)
        let anchor = #"href="https://example.org/venue?a=1&amp;b=2">Venue &amp; &lt;Hall&gt;</a>"#
        #expect(html.contains(anchor))
        #expect(html.contains("A &amp; &lt;friendly&gt; conference at "))
        if !hasEdition {
            let description = try #require(html.firstMatch(of: /<meta name="description" content="([^"]*)"/)?.1)
            #expect(description.contains("Venue &amp;"))
            #expect(!description.contains("<a "))
            #expect(!description.contains("https://example.org/venue"))
            let directory = try String(contentsOf: root.appending(path: "conferences/index.html"), encoding: .utf8)
            #expect(directory.contains(anchor))
        }
    }

    @Test(arguments: ["2027-02-04", "2027-02-05", "2029-01-01"])
    func searchMetadataFollowsFeaturedEdition(day: String) async throws {
        var catalog = CatalogFixture.make()
        var next = catalog.editions[0]
        next.id = "sample-2028"
        next.slug = "2028"
        next.label = "2028"
        next.startDate = "2028-02-02"
        next.endDate = "2028-02-04"
        catalog.editions.append(next)
        var empty = catalog.conferences[0]
        empty.id = "empty"
        empty.slug = "empty"
        catalog.conferences.append(empty)
        try catalog.validate()
        let date = try #require(ISO8601DateFormatter().date(from: day + "T12:00:00Z"))
        let expectedYear = day == "2027-02-04" ? "2027" : "2028"
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: false, url: try #require(URL(string: "https://custom.example.org")), publicationDate: date)
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let hub = try String(contentsOf: root.appending(path: "conferences/sample/index.html"), encoding: .utf8)
        let canonical = "https://custom.example.org/conferences/sample/\(expectedYear)/"
        #expect(hub.contains("href=\"\(canonical)\" rel=\"canonical\""))
        #expect(hub.contains("property=\"og:url\" content=\"\(canonical)\""))
        #expect(hub.components(separatedBy: "rel=\"canonical\"").count == 2)
        #expect(hub.components(separatedBy: "property=\"og:url\"").count == 2)
        let home = try String(contentsOf: root.appending(path: "index.html"), encoding: .utf8)
        #expect(home.contains("<title>Indie bundles for Swift &amp; iOS conferences"))
        #expect(home.contains("content=\"https://custom.example.org/assets/brand/sponsored-by-indies/sponsored-by-indies-social-preview.png?v="))
        let directory = try String(contentsOf: root.appending(path: "conferences/index.html"), encoding: .utf8)
        let contribution = try String(contentsOf: root.appending(path: "participate/indies/index.html"), encoding: .utf8)
        #expect(contribution.contains("value=\"Sample Conference 2027\"") == (day <= "2027-02-04"))
        #expect(contribution.contains("value=\"Sample Conference 2028\"") == (day <= "2028-02-04"))
        #expect(directory.contains("href=\"/conferences/sample/\(expectedYear)/\""))
        let sitemap = try String(contentsOf: root.appending(path: "sitemap.xml"), encoding: .utf8)
        #expect(!sitemap.contains("<loc>https://custom.example.org/conferences/sample/</loc>"))
        #expect(!sitemap.contains("/access/"))
        #expect(sitemap.contains("<loc>https://custom.example.org/conferences/empty/</loc>"))
        for year in ["2027", "2028"] {
            #expect(sitemap.contains("<loc>https://custom.example.org/conferences/sample/\(year)/</loc>"))
            let edition = try String(contentsOf: root.appending(path: "conferences/sample/\(year)/index.html"), encoding: .utf8)
            #expect(edition.contains("href=\"https://custom.example.org/conferences/sample/\(year)/\" rel=\"canonical\""))
        }
    }

    @Test(arguments: [
        ("2026-11-19T12:00:00Z", "Sample Conference"),
        ("2027-02-03T12:00:00Z", "Sample Conference"),
        ("2027-03-01T12:00:00Z", "Later Conference"),
        ("2028-01-01T12:00:00Z", nil)
    ] as [(String, String?)])
    func conferenceDirectoryKeepsEveryConferenceAsTheFeaturedEditionChanges(
        dateString: String, featuredName: String?
    ) async throws {
        var catalog = CatalogFixture.make()
        var laterConference = catalog.conferences[0]
        laterConference.id = "later"
        laterConference.slug = "later"
        laterConference.name = "Later Conference"
        catalog.conferences.insert(laterConference, at: 0)
        var unannouncedConference = laterConference
        unannouncedConference.id = "unannounced"
        unannouncedConference.slug = "unannounced"
        unannouncedConference.name = "Conference Without Editions"
        catalog.conferences.append(unannouncedConference)
        var laterEdition = catalog.editions[0]
        laterEdition.id = "later-2027"
        laterEdition.conferenceID = laterConference.id
        laterEdition.slug = "later-2027"
        laterEdition.label = "Later 2027"
        laterEdition.startDate = "2027-05-10"
        laterEdition.endDate = "2027-05-12"
        catalog.editions.append(laterEdition)
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let date = try #require(ISO8601DateFormatter().date(from: dateString))
        var site = IndiesSite(
            catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")),
            publicationDate: date)
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "conferences/index.html"), encoding: .utf8)
        let grid = try #require(html.range(of: "class=\"conference-card-grid\""))
        let benefits = try #require(html.range(of: "id=\"benefits-title\""))
        let remainingCards = html[grid.lowerBound..<benefits.lowerBound]
        #expect(remainingCards.contains("Conference Without Editions"))
        if let featuredName {
            let featured = try #require(html.range(of: "class=\"conference-card conference-card-featured\""))
            #expect(featured.lowerBound < grid.lowerBound)
            let featuredCard = html[featured.lowerBound..<grid.lowerBound]
            let otherName = featuredName == "Sample Conference" ? "Later Conference" : "Sample Conference"
            #expect(featuredCard.contains(featuredName))
            #expect(!featuredCard.contains(otherName))
            #expect(remainingCards.contains(otherName))
        } else {
            #expect(!html.contains("conference-card-featured"))
            #expect(remainingCards.contains("Sample Conference"))
            #expect(remainingCards.contains("Later Conference"))
        }
    }

    @Test(arguments: [0, 1, 2, 4])
    func conferenceDirectoryKeepsRecentPastEditionsOutsideTheArchive(pastCount: Int) async throws {
        var catalog = CatalogFixture.make()
        let template = catalog.editions[0]
        for year in (2022..<(2022 + pastCount)).reversed() {
            var edition = template
            edition.id = "sample-\(year)"
            edition.slug = "\(year)"
            edition.label = "\(year)"
            edition.dateLabel = "2–4 February \(year)"
            edition.startDate = "\(year)-02-02"
            edition.endDate = "\(year)-02-04"
            catalog.editions.append(edition)
        }
        // Include a later edition of the same conference: no edition may be lost or duplicated.
        var future = template
        future.id = "sample-2028"
        future.slug = "2028"
        future.label = "2028"
        future.dateLabel = "2–4 February 2028"
        future.startDate = "2028-02-02"
        future.endDate = "2028-02-04"
        catalog.editions.insert(future, at: 0)
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let date = try #require(ISO8601DateFormatter().date(from: "2026-11-20T12:00:00Z"))
        var site = IndiesSite(catalog: catalog, preview: true,
                              url: try #require(URL(string: "https://example.org")), publicationDate: date)
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "conferences/index.html"), encoding: .utf8)
        let next = try #require(html.firstMatch(of: /<section[^>]*aria-labelledby="next-conference-title"[\s\S]*?<\/section>/)?.0)
        let upcoming = try #require(html.firstMatch(of: /<section[^>]*aria-labelledby="upcoming-conferences-title"[\s\S]*?<\/section>/)?.0)
        #expect(next.contains("/conferences/sample/2027/"))
        #expect(!next.contains("/conferences/sample/2028/"))
        #expect(upcoming.contains("/conferences/sample/2028/"))
        #expect(!upcoming.contains("/conferences/sample/2027/"))
        #expect(html.contains("id=\"past-conferences-title\"") == (pastCount > 0))
        #expect(html.contains("id=\"past-conferences-archive\"") == (pastCount > 2))
        if pastCount > 0 {
            let past = try #require(html.firstMatch(of: /<section[^>]*aria-labelledby="past-conferences-title"[\s\S]*?<\/section>/)?.0)
            let recent = past.components(separatedBy: "<details")[0]
            #expect(recent.components(separatedBy: "<article ").count - 1 == min(2, pastCount))
            for year in 2022..<(2022 + pastCount) {
                #expect(recent.contains("/conferences/sample/\(year)/") == (year >= 2022 + pastCount - 2))
            }
            if pastCount > 2 {
                let archive = try #require(past.firstMatch(of: /<details[\s\S]*?<\/details>/)?.0)
                #expect(!archive.contains(" open"))
                #expect(archive.contains("Show all past conferences"))
                #expect(archive.contains("Show fewer"))
                let newest = try #require(past.range(of: "/conferences/sample/2025/"))
                let previous = try #require(past.range(of: "/conferences/sample/2024/"))
                #expect(newest.lowerBound < previous.lowerBound)
                // Browser checks use this generated fixture to exercise a real archive before
                // the public catalogue has enough past editions. It is never published.
                let fixtureFolder = source.appending(path: ".build/browser-fixtures")
                try FileManager.default.createDirectory(at: fixtureFolder, withIntermediateDirectories: true)
                try html.write(to: fixtureFolder.appending(path: "conference-directory.html"), atomically: true, encoding: .utf8)
            }
        }
    }
}
