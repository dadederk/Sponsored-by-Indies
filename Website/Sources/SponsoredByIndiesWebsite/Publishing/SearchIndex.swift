import Foundation

/// One page registry drives canonical metadata and sitemap inclusion.
struct SearchIndex {
    let pages: [MarketingPage]
    let siteURL: URL

    func canonicalURL(for url: URL) -> URL {
        guard let page = page(for: url) else {
            preconditionFailure("Page is missing from the search registry: \(url)")
        }
        return absoluteURL(for: page.canonicalPath)
    }

    func isIndexable(_ url: URL) -> Bool {
        page(for: url)?.isIndexable == true
    }

    private func page(for url: URL) -> MarketingPage? {
        guard url.scheme == siteURL.scheme, url.host == siteURL.host, url.port == siteURL.port else { return nil }
        // Ignite appends an empty path for the home page. Foundation versions
        // differ in equality for that URL and the same root with a trailing slash.
        let route = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return pages.first { $0.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == route }
    }

    private func absoluteURL(for path: String) -> URL {
        var components = URLComponents(url: siteURL, resolvingAgainstBaseURL: true)!
        components.path = path
        return components.url!
    }

    func install(in directory: URL) throws {
        let entries = pages.filter { $0.isIndexable && $0.path == $0.canonicalPath }
            .map { "<url><loc>\(escaped(absoluteURL(for: $0.path).absoluteString))</loc></url>" }
            .joined()
        // Ignite includes every static route in its sitemap. Replace it in
        // staging so utility routes and mirrored hubs do not compete with editions.
        let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\(entries)</urlset>"
        try xml.write(to: directory.appending(path: "sitemap.xml"), atomically: true, encoding: .utf8)
    }
}
