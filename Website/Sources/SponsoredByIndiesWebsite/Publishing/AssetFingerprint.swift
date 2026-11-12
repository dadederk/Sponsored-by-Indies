import CryptoKit
import Foundation

/// Version shared styles and artwork from their inputs, including SVG paint tokens.
enum AssetFingerprint {
    static func make(in sourceDirectory: URL, tokens: String = DesignTokens.stylesheet()) throws -> String {
        var digest = SHA256()
        digest.update(data: Data(tokens.utf8))
        let paths = (["styles.css"] + DesignTokens.brandAssetNames).map { "Assets/\($0)" }
            + ["Sources/SponsoredByIndiesWebsite/Publishing/SocialPreview.swift"]
        for name in paths.sorted() {
            let data = try Data(contentsOf: sourceDirectory.appending(path: name))
            digest.update(data: Data(name.utf8))
            digest.update(data: Data(SHA256.hash(data: data)))
        }
        return digest.finalize().prefix(6)
            .map { String(("0" + String($0, radix: 16)).suffix(2)) }.joined()
    }
}
