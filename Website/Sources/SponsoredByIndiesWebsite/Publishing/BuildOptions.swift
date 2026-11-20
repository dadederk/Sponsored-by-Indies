import Foundation

/// Parse before clearing generated output so invalid invocations leave it intact.
struct BuildOptions {
    let isPublic: Bool
    let validateOnly: Bool
    let verifyPrices: Bool
    let checkMaintenance: Bool
    let siteURL: URL
    let identity: SiteIdentity
    let partnerArtworkEditionID: String?
    let partnerProjectID: String?
    let partnerGroupID: String?
    let allPartners: Bool

    init(arguments: [String]) throws {
        var isPublic = false
        var validateOnly = false
        var verifyPrices = false
        var checkMaintenance = false
        var providedURL: String?
        var identity: SiteIdentity?
        var partnerArtworkEditionID: String?
        var partnerProjectID: String?
        var partnerGroupID: String?
        var allPartners = false
        var remaining = arguments.makeIterator()
        while let argument = remaining.next() {
            switch argument {
            case "--public": isPublic = true
            case "--validate-only": validateOnly = true
            case "--verify-prices": verifyPrices = true
            case "--check-maintenance": checkMaintenance = true
            case "--all-partners":
                guard !allPartners else { throw CatalogError.invalid("Choose --all-partners once.") }
                allPartners = true
            case "--partner-artwork", "--project", "--group":
                guard let value = remaining.next(), !value.hasPrefix("--"), !value.isEmpty else {
                    throw CatalogError.invalid("\(argument) requires one ID.")
                }
                if argument == "--partner-artwork" {
                    guard partnerArtworkEditionID == nil else { throw CatalogError.invalid("Choose one artwork edition.") }
                    partnerArtworkEditionID = value
                } else if argument == "--project" {
                    guard partnerProjectID == nil else { throw CatalogError.invalid("Choose one artwork project.") }
                    partnerProjectID = value
                } else {
                    guard partnerGroupID == nil else { throw CatalogError.invalid("Choose one artwork group.") }
                    partnerGroupID = value
                }
            case "--site":
                guard identity == nil, let value = remaining.next(), let selected = SiteIdentity(rawValue: value) else {
                    throw CatalogError.invalid("--site requires sponsored or showcase, once.")
                }
                identity = selected
            case "--site-url":
                guard providedURL == nil, let value = remaining.next(), !value.hasPrefix("--") else {
                    throw CatalogError.invalid("--site-url requires one URL.")
                }
                providedURL = value
            default: throw CatalogError.invalid("Unknown argument: \(argument)")
            }
        }
        guard [verifyPrices, validateOnly, checkMaintenance, partnerArtworkEditionID != nil].filter({ $0 }).count <= 1 else {
            throw CatalogError.invalid("Choose one standalone check or --partner-artwork.")
        }
        guard (partnerProjectID == nil && partnerGroupID == nil && !allPartners) || partnerArtworkEditionID != nil else {
            throw CatalogError.invalid("--project, --group and --all-partners require --partner-artwork.")
        }
        guard [partnerProjectID != nil, partnerGroupID != nil, allPartners].filter({ $0 }).count <= 1 else {
            throw CatalogError.invalid("Choose --project, --group or --all-partners.")
        }
        guard partnerArtworkEditionID == nil || (!isPublic && identity == nil && providedURL == nil) else {
            throw CatalogError.invalid("Partner artwork is separate from website generation; omit --public, --site and --site-url.")
        }
        guard !isPublic || validateOnly || providedURL != nil else {
            throw CatalogError.invalid("Public builds require --site-url https://your-chosen-domain.")
        }
        let selected = identity ?? .sponsored
        let value = providedURL ?? selected.previewURL
        guard let url = URL(string: value),
              let host = url.host, !host.isEmpty,
              ["http", "https"].contains(url.scheme),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/",
              !isPublic || validateOnly || url.scheme == "https" else {
            throw CatalogError.invalid("Expected a site root URL without credentials, query, or fragment; public builds require HTTPS.")
        }
        self.isPublic = isPublic
        self.validateOnly = validateOnly
        self.verifyPrices = verifyPrices
        self.checkMaintenance = checkMaintenance
        self.siteURL = url
        self.identity = selected
        self.partnerArtworkEditionID = partnerArtworkEditionID
        self.partnerProjectID = partnerProjectID
        self.partnerGroupID = partnerGroupID
        self.allPartners = allPartners
    }
}
