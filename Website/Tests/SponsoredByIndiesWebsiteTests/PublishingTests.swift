import Foundation
import Ignite
import Testing

@testable import SponsoredByIndiesWebsite

// Ignite keeps a shared publishing context across suspension points. Serialize
// publishing tests while leaving the pure catalogue tests free to run in parallel.
@Suite(.serialized)
@MainActor
struct PublishingTests {
    var source: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }
}
