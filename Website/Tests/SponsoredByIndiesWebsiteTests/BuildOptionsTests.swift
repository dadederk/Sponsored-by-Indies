import Testing
@testable import SponsoredByIndiesWebsite

struct BuildOptionsTests {
    @Test(arguments: [
        ["--unknown"], ["--site"], ["--site", "unknown"], ["--site", "showcase", "--site", "sponsored"],
        ["--site-url"], ["--site-url", "garbage"], ["--public"],
        ["--public", "--site-url", "http://example.org"],
        ["--site-url", "https://example.org/path"],
        ["--site-url", "https://example.org?query=1"],
        ["--site-url", "https://user:password@example.org"],
        ["--site-url", "https://example.org", "--site-url", "https://other.org"],
        ["--validate-only", "--verify-prices"], ["--verify-prices", "--validate-only"],
        ["--check-maintenance", "--validate-only"], ["--verify-prices", "--check-maintenance"],
        ["--partner-artwork"], ["--project", "dee"], ["--partner-artwork", "--project", "dee"],
        ["--partner-artwork", "arctic-2027", "--validate-only"],
        ["--partner-artwork", "arctic-2027", "--public"],
        ["--partner-artwork", "arctic-2027", "--site", "showcase"],
        ["--partner-artwork", "arctic-2027", "--site-url", "https://example.org"],
        ["--partner-artwork", "arctic-2027", "--partner-artwork", "arctic-2027"],
        ["--partner-artwork", "arctic-2027", "--project", "dee", "--project", "dee"],
        ["--all-partners"], ["--group", "pair"],
        ["--partner-artwork", "arctic-2027", "--group"],
        ["--partner-artwork", "arctic-2027", "--all-partners", "--project", "dee"],
        ["--partner-artwork", "arctic-2027", "--all-partners", "--group", "pair"],
        ["--partner-artwork", "arctic-2027", "--project", "dee", "--group", "pair"],
        ["--partner-artwork", "arctic-2027", "--group", "pair", "--group", "other"],
        ["--partner-artwork", "arctic-2027", "--all-partners", "--all-partners"]
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
        let showcase = try BuildOptions(arguments: ["--site", "showcase"])
        #expect(showcase.identity == .showcase)
        #expect(showcase.siteURL.absoluteString == "http://localhost:8001")
        #expect(showcase.identity.buildDirectory(preview: true) == "BuildIndies")
        #expect(showcase.identity.buildDirectory(preview: false) == "BuildIndiesPublic")
        let artwork = try BuildOptions(arguments: ["--partner-artwork", "arctic-2027", "--project", "dee"])
        #expect(artwork.partnerArtworkEditionID == "arctic-2027")
        #expect(artwork.partnerProjectID == "dee")
        #expect(try BuildOptions(arguments: ["--partner-artwork", "arctic-2027"]).partnerProjectID == nil)
        #expect(try BuildOptions(arguments: ["--partner-artwork", "arctic-2027", "--all-partners"]).allPartners)
        #expect(try BuildOptions(arguments: ["--partner-artwork", "arctic-2027", "--group", "pair"]).partnerGroupID == "pair")
    }
}
