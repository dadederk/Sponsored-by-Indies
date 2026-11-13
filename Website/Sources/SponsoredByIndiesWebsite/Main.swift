import Foundation
import Ignite

@main
struct SponsoredByIndiesWebsite {
    @MainActor
    static func main() async throws {
        let options = try BuildOptions(arguments: Array(CommandLine.arguments.dropFirst()))
        let preview = !options.isPublic
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try Catalog.load(from: source.appendingPathComponent("Data"))
        if options.verifyPrices {
            try await PriceVerification.verify(catalog)
            return
        }
        try catalog.validatePriceFreshness(on: .now)
        if options.validateOnly {
            print("Catalogue valid: \(catalog.conferences.count) conference(s), \(catalog.editions.count) edition(s).")
            return
        }
        let baseURL = options.siteURL
        var site = IndiesSite(catalog: catalog, preview: preview, url: baseURL)
        let directory = source.appendingPathComponent(preview ? "Build" : "BuildPublic")
        let staging = source.appendingPathComponent(".build/site-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        // Generate a fresh tree, so failures preserve the previous output and
        // removed profiles cannot linger in a successful build.
        try await site.generate(sourceDirectory: source, buildDirectory: staging)
        try BuildOutput.install(staging, at: directory)
        print("\(preview ? "Local preview" : "Public") site generated at \(directory.path)")
    }
}
