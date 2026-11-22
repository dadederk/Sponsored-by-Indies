import Foundation
import Ignite
import Testing

@testable import SponsoredByIndiesWebsite

extension PublishingTests {
    @Test(arguments: [nil, "https://example.org/contact?source=indies&lang=en"] as [String?])
    func participationInterestMatchesTheConfiguredContactRoute(contact: String?) async throws {
        var catalog = CatalogFixture.make()
        catalog.contactURL = contact
        try catalog.validate()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = IndiesSite(catalog: catalog, preview: true, url: try #require(URL(string: "https://example.org")))
        try await site.generate(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appending(path: "participate/indies/index.html"), encoding: .utf8)
        #expect(!html.contains("id=\"contribution-form\""))
        #expect(!html.contains("src=\"/contribution.mjs\""))
        #expect(!html.contains("Opens an email draft."))
        #expect(!html.contains("use the form below"))
        #expect(html.contains("A contribution contact route will be available here soon.") == (contact == nil))
        #expect(html.contains("Express indie interest") == (contact != nil))
        if let contact {
            #expect(html.contains("href=\"\(escaped(contact))\""))
            #expect(html.contains("through our contact page."))
        }
        let conference = try String(contentsOf: root.appending(path: "participate/conferences/index.html"), encoding: .utf8)
        #expect(!conference.contains("id=\"conference-interest-form\""))
        #expect(!conference.contains("src=\"/conference-interest.mjs\""))
        #expect(!conference.contains("Prefer a form?"))
        #expect(!conference.contains("Opens an email draft."))
        #expect(conference.contains("A conference contact route will be available here soon.") == (contact == nil))
        #expect(conference.contains("Express conference interest") == (contact != nil))
        if let contact { #expect(conference.contains("href=\"\(escaped(contact))\"")) }
    }

    @Test func textareaOptionsComposeIndependently() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var site = FormOptionsSite(url: try #require(URL(string: "https://example.org")))
        try await site.publish(sourceDirectory: source, buildDirectory: root)
        let html = try String(contentsOf: root.appendingPathComponent("index.html"), encoding: .utf8)
        for index in 0..<8 {
            let range = try #require(html.range(of: "<textarea[^>]*id=\"field-\(index)\"[^>]*>", options: .regularExpression))
            let control = String(html[range])
            #expect((control.range(of: "\\srequired(?:\\s|=|>)", options: .regularExpression) != nil) == (index & 1 != 0))
            #expect((control.range(of: "\\sreadonly(?:\\s|=|>)", options: .regularExpression) != nil) == (index & 2 != 0))
            #expect(control.contains("data-resource-field=\"description\"") == (index & 4 != 0))
            #expect(control.contains("aria-describedby=\"help\""))
            #expect(html.contains("for=\"field-\(index)\""))
        }
    }
}

private struct FormOptionsSite: Site {
    let url: URL
    var name = "Form option checks"
    var layout = MarketingLayout(preview: true)
    var feedConfiguration: FeedConfiguration? = nil
    var builtInIconsEnabled: BootstrapOptions = .none
    var homePage: MarketingPage {
        MarketingPage(path: "/", title: "Form option checks", description: "Synthetic form controls.") {
            Text("Form option checks").font(.title1)
            Text("Field help").id("help")
            for index in 0..<8 {
                FormFields.multiline(
                    "Field \(index)", id: "field-\(index)", required: index & 1 != 0,
                    readOnly: index & 2 != 0, resourceKey: index & 4 != 0 ? "description" : nil,
                    helpID: "help")
            }
        }
    }
}
