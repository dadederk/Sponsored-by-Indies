import Foundation
import Ignite
import Testing

@testable import SponsoredByIndiesWebsite

@MainActor
struct SearchIndexTests {
    private var index: SearchIndex {
        SearchIndex(pages: [
            MarketingPage(path: "/", title: "Home", description: "Home") { Text("Home") },
            MarketingPage(path: "/shortcut/", title: "Shortcut", description: "Shortcut", canonicalPath: "/dated/") { Text("Shortcut") }
        ], siteURL: URL(string: "https://example.org")!)
    }

    @Test(arguments: ["https://example.org", "https://example.org/"])
    func homeURLRepresentationsResolveToOneCanonical(value: String) throws {
        let url = try #require(URL(string: value))
        #expect(index.canonicalURL(for: url).absoluteString == "https://example.org/")
        #expect(index.isIndexable(url))
    }

    @Test func igniteEmptyPathAndMirroredRouteResolve() throws {
        let origin = try #require(URL(string: "https://example.org"))
        #expect(index.canonicalURL(for: origin.appending(path: "")).absoluteString == "https://example.org/")
        #expect(index.canonicalURL(for: origin.appending(path: "shortcut/")).absoluteString == "https://example.org/dated/")
    }

    @Test(arguments: ["https://other.example/", "http://example.org/", "https://example.org:8080/", "https://example.org/missing/"])
    func unrelatedURLsAreNotIndexable(value: String) throws {
        #expect(!index.isIndexable(try #require(URL(string: value))))
    }
}
