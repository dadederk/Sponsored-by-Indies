import Foundation
import CoreFoundation

/// A read-only check of public price references. It never updates approved
/// content or chooses one of several prices automatically.
enum PriceVerification {
    typealias Fetch = @MainActor (URLRequest) async throws -> (Data, URLResponse)

    @MainActor
    static func requestData(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }

    /// Retry transport interruptions and temporary HTTP failures only. A price
    /// mismatch or an unexpected redirect must remain visible for human review.
    @MainActor
    static func loadPage(_ url: URL, format: SavingEstimate.SourceFormat?, fetch: Fetch = requestData,
                         pause: @MainActor () async throws -> Void = { try await Task.sleep(for: .seconds(1)) }) async throws -> String {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        for attempt in 1...3 {
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await fetch(request)
            } catch let error as URLError {
                let temporary: Set<URLError.Code> = [.timedOut, .cannotFindHost, .cannotConnectToHost,
                                                     .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet]
                if attempt < 3, temporary.contains(error.code) {
                    try await pause()
                    continue
                }
                throw CatalogError.invalid("Could not fetch \(url.absoluteString) after \(attempt) attempt(s): \(error.localizedDescription)")
            }
            guard let http = response as? HTTPURLResponse else {
                throw CatalogError.invalid("Non-HTTP response from \(url.absoluteString).")
            }
            if attempt < 3, http.statusCode == 408 || http.statusCode == 429 || (500...599).contains(http.statusCode) {
                try await pause()
                continue
            }
            guard http.statusCode == 200 else {
                throw CatalogError.invalid("HTTP \(http.statusCode) from \(http.url?.absoluteString ?? url.absoluteString) after \(attempt) attempt(s).")
            }
            guard let finalURL = http.url, finalURL.scheme == "https", finalURL.host == url.host,
                  (format == .schemaOrg || (finalURL.path.hasPrefix("/us/app/") && finalURL.lastPathComponent == url.lastPathComponent)) else {
                throw CatalogError.invalid("Unexpected price-source redirect: \(url.absoluteString) → \(http.url?.absoluteString ?? "unknown URL").")
            }
            guard let html = String(data: data, encoding: .utf8) else {
                throw CatalogError.invalid("The price source did not return UTF-8 text: \(url.absoluteString).")
            }
            return html
        }
        preconditionFailure("Every request attempt must return, retry or throw.")
    }

    static func listedPrices(in html: String, plan: String) throws -> [Decimal] {
        let pattern = #"<div class="text-pair[^\"]*"><span>([^<]+)</span>\s*<span>\$([0-9]+(?:\.[0-9]{2})?)</span>"#
        let expression = try NSRegularExpression(pattern: pattern)
        let source = html as NSString
        var prices = Set<Decimal>()
        for match in expression.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            guard source.substring(with: match.range(at: 1)) == plan,
                  let amount = Decimal(string: source.substring(with: match.range(at: 2)), locale: Locale(identifier: "en_US_POSIX")) else { continue }
            prices.insert(amount)
        }
        guard !prices.isEmpty else { throw CatalogError.invalid("No USD prices found for exact plan label ‘\(plan)’. Review the source; do not guess.") }
        return prices.sorted()
    }

    /// Match the named product's structured USD offer, rather than scrape an
    /// unrelated promotion, team tier or regional price from visible page text.
    static func structuredPrices(in html: String, productName: String) throws -> [Decimal] {
        let pattern = #"(?is)<script\b[^>]*\btype\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script\s*>"#
        let expression = try NSRegularExpression(pattern: pattern)
        let source = html as NSString
        func records(_ value: Any) -> [[String: Any]] {
            if let list = value as? [Any] { return list.flatMap(records) }
            guard let object = value as? [String: Any] else { return [] }
            return [object] + (object["@graph"].map(records) ?? [])
        }
        var prices = Set<Decimal>()
        for match in expression.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            let data = Data(source.substring(with: match.range(at: 1)).utf8)
            for product in records(try JSONSerialization.jsonObject(with: data)) where product["name"] as? String == productName {
                guard let offers = product["offers"] else { continue }
                for offer in records(offers) where offer["priceCurrency"] as? String == "USD" {
                    let price: String?
                    if let text = offer["price"] as? String {
                        price = text
                    } else if let number = offer["price"] as? NSNumber,
                              CFGetTypeID(number) != CFBooleanGetTypeID() {
                        price = number.stringValue
                    } else {
                        price = nil
                    }
                    guard let price, price.range(of: #"^[0-9]+(?:\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
                          let amount = Decimal(string: price, locale: Locale(identifier: "en_US_POSIX")), !amount.isNaN, amount >= 0 else {
                        throw CatalogError.invalid("Invalid structured USD price for ‘\(productName)’.")
                    }
                    prices.insert(amount)
                }
            }
        }
        guard !prices.isEmpty else { throw CatalogError.invalid("No structured USD offers found for exact product name ‘\(productName)’. Review the source; do not guess.") }
        return prices.sorted()
    }

    @MainActor
    @discardableResult
    static func verify(_ catalog: Catalog, on date: Date = .now, fetch: Fetch = requestData,
                       summaryURL: URL? = nil) async throws -> PriceVerificationReport {
        let report = await check(catalog, on: date, fetch: fetch)
        print(report.console)
        if let summaryURL {
            let output = try FileHandle(forWritingTo: summaryURL)
            defer { try? output.close() }
            try output.seekToEnd()
            try output.write(contentsOf: Data(report.markdown.utf8))
        }
        try report.requireSuccess()
        return report
    }

    @MainActor
    static func check(_ catalog: Catalog, on date: Date = .now, fetch: Fetch = requestData) async -> PriceVerificationReport {
        let offers = catalog.offersRequiringPriceChecks(on: date).sorted { $0.id < $1.id }
        var pages: [String: String] = [:]
        var report = PriceVerificationReport()
        for offer in offers {
            guard let evidence = offer.savingEstimate else { continue }
            func record(_ status: PriceVerificationReport.Status, _ message: String) {
                report.entries.append(.init(offerID: offer.id, status: status, message: message, sourceURL: evidence.sourceURL))
            }
            do {
                try evidence.validateFreshness(for: offer.id, on: date)
                if evidence.sourceFormat == .manual {
                    let confirmation = evidence.review == .provisional ? " Maker confirmation is still required." : ""
                    record(.manual, "Manual evidence reviewed \(evidence.verifiedOn); no automatic match is available.\(confirmation)")
                    continue
                }
                guard let url = URL(string: evidence.sourceURL), url.scheme == "https" else {
                    throw CatalogError.invalid("Price references require HTTPS.")
                }
                if evidence.sourceFormat != .schemaOrg {
                    guard url.host == "apps.apple.com", url.path.hasPrefix("/us/app/") else {
                        throw CatalogError.invalid("App Store references must use the US storefront.")
                    }
                }
                let html: String
                if let cached = pages[evidence.sourceURL] { html = cached }
                else {
                    html = try await loadPage(url, format: evidence.sourceFormat, fetch: fetch)
                    pages[evidence.sourceURL] = html
                }
                let observed: [Decimal]
                if evidence.sourceFormat == .schemaOrg {
                    observed = try structuredPrices(in: html, productName: evidence.sourceProductName ?? "")
                } else {
                    observed = try listedPrices(in: html, plan: evidence.plan)
                }
                guard observed == evidence.observedPricesUSD.sorted() else {
                    throw CatalogError.invalid("‘\(evidence.plan)’: recorded \(evidence.observedPricesUSD.sorted().map(\.usdLabel).joined(separator: ", ")); found \(observed.map(\.usdLabel).joined(separator: ", ")). Review regular versus temporary pricing, discount and evidence date.")
                }
                let confirmation = evidence.review == .provisional ? " Maker confirmation is still required." : ""
                record(evidence.review == .provisional ? .provisional : .match, evidence.calculationDescription + confirmation)
            } catch { record(.failed, String(describing: error)) }
        }
        return report
    }
}
