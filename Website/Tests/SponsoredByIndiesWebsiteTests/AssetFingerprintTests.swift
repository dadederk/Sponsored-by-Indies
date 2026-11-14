import Foundation
import Testing
@testable import SponsoredByIndiesWebsite

struct AssetFingerprintTests {
    @Test func versionsFollowStylesArtworkAndTokens() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? files.removeItem(at: root) }
        let assets = root.appending(path: "Assets")
        try files.createDirectory(at: assets, withIntermediateDirectories: true)
        for name in ["styles.css"] + DesignTokens.brandAssetNames {
            try "Original \(name)".write(to: assets.appending(path: name), atomically: true, encoding: .utf8)
        }
        let renderer = root.appending(path: "Sources/SponsoredByIndiesWebsite/Publishing/SocialPreview.swift")
        try files.createDirectory(at: renderer.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "Original artwork renderer".write(to: renderer, atomically: true, encoding: .utf8)
        let identity = renderer.deletingLastPathComponent().appending(path: "SiteIdentity.swift")
        try "Original site identities".write(to: identity, atomically: true, encoding: .utf8)
        let bundle = renderer.deletingLastPathComponent().appending(path: "BundleArtwork.swift")
        try "Original bundle artwork".write(to: bundle, atomically: true, encoding: .utf8)
        let original = try AssetFingerprint.make(in: root)
        #expect(try AssetFingerprint.make(in: root) == original)
        try "Updated layout".write(to: assets.appending(path: "styles.css"), atomically: true, encoding: .utf8)
        let changedStyle = try AssetFingerprint.make(in: root)
        #expect(changedStyle != original)
        try "Updated logo shape".write(to: assets.appending(path: "logo.svg"), atomically: true, encoding: .utf8)
        let changedLogo = try AssetFingerprint.make(in: root)
        #expect(changedLogo != changedStyle)
        #expect(try AssetFingerprint.make(in: root, tokens: "Updated palette") != changedLogo)
        try "Updated sharing layout".write(to: renderer, atomically: true, encoding: .utf8)
        #expect(try AssetFingerprint.make(in: root) != changedLogo)
        let changedRenderer = try AssetFingerprint.make(in: root)
        try "Changed headline".write(to: identity, atomically: true, encoding: .utf8)
        #expect(try AssetFingerprint.make(in: root) != changedRenderer)
        let changedIdentity = try AssetFingerprint.make(in: root)
        try "Changed bundle artwork".write(to: bundle, atomically: true, encoding: .utf8)
        #expect(try AssetFingerprint.make(in: root) != changedIdentity)
    }
}
