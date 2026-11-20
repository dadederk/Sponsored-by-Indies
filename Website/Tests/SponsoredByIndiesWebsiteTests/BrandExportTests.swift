import AppKit
import Testing
@testable import SponsoredByIndiesWebsite

struct BrandExportTests {
    @Test @MainActor func transparentLogosShareTheirOutlineAndBlackContainsNoColour() throws {
        let files = FileManager.default
        let directory = files.temporaryDirectory.appending(path: UUID().uuidString)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: directory) }
        let assets = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appending(path: "Assets")
        for name in ["logo.svg", "logo-inverse.svg", "favicon.svg"] {
            let source = try String(contentsOf: assets.appending(path: name), encoding: .utf8)
            try files.createDirectory(at: directory.appending(path: ArtworkPaths.vectorAssets[name]!).deletingLastPathComponent(), withIntermediateDirectories: true)
            try DesignTokens.renderSVG(source).write(to: directory.appending(path: ArtworkPaths.vectorAssets[name]!), atomically: true, encoding: .utf8)
        }
        try SocialPreview.install(in: directory)
        func bitmap(_ variant: String) throws -> NSBitmapImageRep {
            let data = try Data(contentsOf: directory.appending(path: ArtworkPaths.brandFile("logo-\(variant)-transparent")))
            return try #require(NSBitmapImageRep(data: data))
        }
        let colour = try bitmap("full-colour")
        let black = try bitmap("black")
        #expect(colour.pixelsWide == 4800 && colour.pixelsHigh == 1400)
        #expect(black.pixelsWide == colour.pixelsWide && black.pixelsHigh == colour.pixelsHigh)
        var sawTransparent = false
        var sawOpaque = false
        var sawColour = false
        // Sample the canvas, including clear space, solid strokes and antialiased edges.
        for y in stride(from: 0, to: colour.pixelsHigh, by: 7) {
            for x in stride(from: 0, to: colour.pixelsWide, by: 7) {
                let original = try #require(colour.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let mono = try #require(black.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                #expect(abs(original.alphaComponent - mono.alphaComponent) < 0.005)
                if mono.alphaComponent > 0 {
                    #expect(mono.redComponent == 0 && mono.greenComponent == 0 && mono.blueComponent == 0)
                }
                sawTransparent = sawTransparent || original.alphaComponent == 0
                sawOpaque = sawOpaque || original.alphaComponent == 1
                sawColour = sawColour || (original.alphaComponent == 1 && original.blueComponent > 0.5)
            }
        }
        #expect(sawTransparent && sawOpaque && sawColour)
    }
}
