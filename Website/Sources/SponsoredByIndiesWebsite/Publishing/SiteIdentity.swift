import Foundation

/// Two publications share content and components, while retaining their own URLs.
enum SiteIdentity: String {
    case sponsored
    case showcase

    static let showcasePreviewPath = "/by-indies-preview/"
    static let wordmarkName = "indies."

    var name: String { self == .sponsored ? "Sponsored by Indies" : "By Indies" }
    var publicURL: String { self == .sponsored ? "https://sponsored.byindies.com" : "https://byindies.com" }
    var previewURL: String { self == .sponsored ? "http://localhost:8000" : "http://localhost:8001" }
    var headline: String { self == .sponsored ? "Amazing conferences." : "Wonderful projects." }
    var emphasis: String { self == .sponsored ? "A little extra." : "By awesome indies." }
    var summary: String {
        self == .sponsored
            ? "Indie bundles for iOS, Swift and Apple developer conferences."
            : "Discover the projects and people supporting our conference community."
    }
    var imageDescription: String { "\(name). \(headline) \(emphasis) \(summary)" }

    func baseURL(preview: Bool) -> String { preview ? previewURL : publicURL }

    func buildDirectory(preview: Bool) -> String {
        switch (self, preview) {
        case (.sponsored, true): "Build"
        case (.sponsored, false): "BuildPublic"
        case (.showcase, true): "BuildIndies"
        case (.showcase, false): "BuildIndiesPublic"
        }
    }

    func sponsoredLink(_ path: String, preview: Bool) -> String {
        self == .sponsored ? path : SiteIdentity.sponsored.baseURL(preview: preview) + path
    }
}
