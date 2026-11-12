import Foundation

/// Parse before clearing generated output so invalid invocations leave it intact.
struct BuildOptions {
    let isPublic: Bool
    let validateOnly: Bool
    let siteURL: URL

    init(arguments: [String]) throws {
        var isPublic = false
        var validateOnly = false
        var providedURL: String?
        var remaining = arguments.makeIterator()
        while let argument = remaining.next() {
            switch argument {
            case "--public": isPublic = true
            case "--validate-only": validateOnly = true
            case "--site-url":
                guard providedURL == nil, let value = remaining.next(), !value.hasPrefix("--") else {
                    throw CatalogError.invalid("--site-url requires one URL.")
                }
                providedURL = value
            default: throw CatalogError.invalid("Unknown argument: \(argument)")
            }
        }
        guard !isPublic || validateOnly || providedURL != nil else {
            throw CatalogError.invalid("Public builds require --site-url https://your-chosen-domain.")
        }
        let value = providedURL ?? "http://localhost:8000"
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
        self.siteURL = url
    }
}
