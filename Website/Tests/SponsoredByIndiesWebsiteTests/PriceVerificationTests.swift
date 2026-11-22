import Foundation
import Testing
@testable import SponsoredByIndiesWebsite

@MainActor
struct PriceVerificationTests {
    let date = try! Date("2026-11-21", strategy: Edition.dayStyle)
    let url = URL(string: "https://apps.apple.com/us/app/sample/id123")!

    func response(_ status: Int = 200, at location: URL? = nil, html: String = "") -> (Data, URLResponse) {
        (Data(html.utf8), HTTPURLResponse(url: location ?? url, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func catalog(manual: Bool = false) -> Catalog {
        var catalog = CatalogFixture.make()
        catalog.offers[0].savingEstimate?.sourceURL = url.absoluteString
        catalog.offers[0].savingEstimate?.sourceFormat = manual ? .manual : .appStore
        return catalog
    }

    @Test(arguments: ["2026-11-21", "2026-10-22", "2026-10-21", "2026-11-22"])
    func manualEvidenceUsesTheSameExpiryAsPublication(checked: String) async throws {
        var catalog = catalog(manual: true)
        catalog.offers[0].savingEstimate?.verifiedOn = checked
        let report = await PriceVerification.check(catalog, on: date, fetch: { _ in
            Issue.record("Manual sources must not be fetched.")
            throw URLError(.cancelled)
        })
        #expect(report.entries.map(\.status) == [(checked == "2026-11-21" || checked == "2026-10-22") ? .manual : .failed])
        #expect(catalog.offers[0].savingEstimate?.verifiedOn == checked)
    }

    @Test func reportsEveryOfferAndPreservesEvidenceOnMismatch() async throws {
        var catalog = catalog()
        var manual = catalog.offers[0]
        manual.id = "manual"
        manual.savingEstimate?.sourceFormat = .manual
        catalog.offers.append(manual)
        let report = await PriceVerification.check(catalog, on: date, fetch: { _ in
            response(html: #"<div class="text-pair"><span>Sample plan</span><span>$7.00</span></div>"#)
        })
        #expect(report.entries.map(\.status) == [.manual, .failed])
        let failure = try #require(report.entries.last)
        #expect(failure.message.contains("recorded US$10.00; found US$7.00"))
        #expect(failure.message.contains("Sample plan"))
        #expect(failure.sourceURL == url.absoluteString)
        #expect(throws: CatalogError.self) { try report.requireSuccess() }
        #expect(catalog.offers[0].savingEstimate?.regularPriceUSD == 10)
        #expect(catalog.offers[0].savingEstimate?.verifiedOn == "2026-11-13")
    }

    @Test func sharedPagesAreFetchedOnceAndAmbiguityRemainsProvisional() async throws {
        var catalog = catalog()
        catalog.offers[0].savingEstimate?.observedPricesUSD = [7, 10]
        catalog.offers[0].savingEstimate?.review = .provisional
        var duplicate = catalog.offers[0]
        duplicate.id = "second-edition-offer"
        catalog.offers.append(duplicate)
        var requests = 0
        let report = await PriceVerification.check(catalog, on: date, fetch: { _ in
            requests += 1
            return response(html: #"<div class="text-pair"><span>Sample plan</span><span>$10.00</span></div><div class="text-pair"><span>Sample plan</span><span>$7.00</span></div>"#)
        })
        #expect(requests == 1)
        #expect(report.entries.map(\.status) == [.provisional, .provisional])
        #expect(report.console.contains("Maker confirmation is still required"))
        try report.requireSuccess()
    }

    @Test(arguments: [408, 429, 500, 503])
    func transientHTTPFailuresRecoverWithoutHidingPersistentFailures(status: Int) async throws {
        var requests = 0
        var pauses = 0
        let html = try await PriceVerification.loadPage(url, format: .appStore, fetch: { _ in
            requests += 1
            return response(requests < 3 ? status : 200, html: "Recovered")
        }, pause: { pauses += 1 })
        #expect(html == "Recovered")
        #expect(requests == 3)
        #expect(pauses == 2)
    }

    @Test(arguments: [404, 503])
    func persistentHTTPFailuresIncludeStatusSourceAndAttemptCount(status: Int) async throws {
        var requests = 0
        do {
            _ = try await PriceVerification.loadPage(url, format: .appStore, fetch: { _ in
                requests += 1
                return response(status)
            }, pause: {})
            Issue.record("An unsuccessful source must fail.")
        } catch {
            #expect(requests == (status == 404 ? 1 : 3))
            #expect(String(describing: error).contains("HTTP \(status)"))
            #expect(String(describing: error).contains(url.absoluteString))
            #expect(String(describing: error).contains("\(requests) attempt(s)"))
        }
    }

    @Test func timeoutRetriesButCancellationDoesNot() async throws {
        var requests = 0
        _ = try await PriceVerification.loadPage(url, format: .appStore, fetch: { _ in
            requests += 1
            if requests == 1 { throw URLError(.timedOut) }
            return response()
        }, pause: {})
        #expect(requests == 2)
        requests = 0
        await #expect(throws: CatalogError.self) {
            _ = try await PriceVerification.loadPage(url, format: .appStore, fetch: { _ in
                requests += 1
                throw URLError(.cancelled)
            }, pause: {})
        }
        #expect(requests == 1)
    }

    @Test(arguments: ["http://apps.apple.com/us/app/sample/id123", "https://apps.apple.com/gb/app/sample/id123",
                      "https://other.example/us/app/sample/id123", "https://apps.apple.com/us/app/other/id456"])
    func redirectsCannotChangeStorefrontHostOrProduct(location: String) async throws {
        var requests = 0
        await #expect(throws: CatalogError.self) {
            _ = try await PriceVerification.loadPage(url, format: .appStore, fetch: { _ in
                requests += 1
                return response(at: URL(string: location)!)
            }, pause: {})
        }
        #expect(requests == 1)
    }

    @Test func failedChecksStillWriteAReadableSummary() async throws {
        let summary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: summary) }
        try "Existing summary\n".write(to: summary, atomically: true, encoding: .utf8)
        await #expect(throws: CatalogError.self) {
            try await PriceVerification.verify(catalog(), on: date, fetch: { _ in response(404) }, summaryURL: summary)
        }
        let text = try String(contentsOf: summary, encoding: .utf8)
        #expect(text.hasPrefix("Existing summary\n"))
        #expect(text.contains("| tool | FAILED |"))
        #expect(text.contains("HTTP 404"))
        #expect(text.contains(url.absoluteString))
    }

    @Test func summaryEscapesEditorialAndSourceText() {
        let report = PriceVerificationReport(entries: [.init(offerID: "sample|<script>", status: .manual,
                                                             message: "Price\n[link](example) *text*", sourceURL: "https://example.com/?a=1&b=2")])
        #expect(report.markdown.contains("sample\\|&lt;script&gt;"))
        #expect(report.markdown.contains("Price \\[link\\](example) \\*text\\*"))
        #expect(report.markdown.contains("a=1&amp;b=2"))
    }
}
