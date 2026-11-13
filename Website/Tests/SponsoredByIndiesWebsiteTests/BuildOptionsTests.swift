import Testing
@testable import SponsoredByIndiesWebsite

struct BuildOptionsTests {
    @Test(arguments: [
        ["--unknown"], ["--site-url"], ["--site-url", "garbage"], ["--public"],
        ["--public", "--site-url", "http://example.org"],
        ["--site-url", "https://example.org/path"],
        ["--site-url", "https://example.org?query=1"],
        ["--site-url", "https://user:password@example.org"],
        ["--site-url", "https://example.org", "--site-url", "https://other.org"],
        ["--validate-only", "--verify-prices"], ["--verify-prices", "--validate-only"],
        ["--check-maintenance", "--validate-only"], ["--verify-prices", "--check-maintenance"]
    ])
    func rejectsInvalidArguments(arguments: [String]) {
        #expect(throws: CatalogError.self) { try BuildOptions(arguments: arguments) }
    }

    @Test func supportsPreviewPublicAndStandaloneValidation() throws {
        #expect(try BuildOptions(arguments: []).siteURL.absoluteString == "http://localhost:8000")
        let options = try BuildOptions(arguments: ["--public", "--site-url", "https://example.org"])
        #expect(options.isPublic)
        #expect(!options.validateOnly)
        #expect(try BuildOptions(arguments: ["--public", "--validate-only"]).validateOnly)
        #expect(try BuildOptions(arguments: ["--verify-prices"]).verifyPrices)
        #expect(try BuildOptions(arguments: ["--check-maintenance"]).checkMaintenance)
    }
}
