import CryptoKit
import Foundation

/// A bundle's public identity supplies both its artwork and sharing metadata.
struct BundleArtwork {
    let conference: Conference
    let edition: Edition

    var imagePath: String {
        // Content changes need a new sharing URL even when the renderer is unchanged.
        let fields = [conference.name, conference.location, edition.label, edition.dateLabel]
            + (conference.branding?.colors ?? [])
        let source = fields.map { "\($0.utf8.count):\($0)" }.joined()
        let version = SHA256.hash(data: Data(source.utf8)).prefix(6)
            .map { String(("0" + String($0, radix: 16)).suffix(2)) }.joined()
        return conference.path + edition.slug + "/social-preview-\(version).png"
    }

    var imageDescription: String {
        "\(conference.name) \(edition.label) indie bundle. \(edition.dateLabel). \(conference.location). Sponsored by Indies."
    }
}
