import Foundation

/// A read-only check of public price references. It never updates approved
/// content or chooses one of several prices automatically.
enum PriceVerification {
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
                    let price = offer["price"] as? String ?? (offer["price"] as? NSNumber)?.stringValue
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
    static func verify(_ catalog: Catalog, on date: Date = .now) async throws {
        let offers = catalog.offersRequiringPriceChecks(on: date).sorted { $0.id < $1.id }
        guard !offers.isEmpty else {
            print("No current or upcoming approved offers have price evidence to check.")
            return
        }
        var pages: [String: String] = [:]
        var failures: [String] = []
        for offer in offers {
            guard let evidence = offer.savingEstimate else { continue }
            do {
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
                    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
                    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                          response.url?.scheme == "https", response.url?.host == url.host,
                          (evidence.sourceFormat == .schemaOrg || response.url?.path.hasPrefix("/us/app/") == true),
                          let text = String(data: data, encoding: .utf8) else {
                        throw CatalogError.invalid("Could not read a successful response from the recorded price source.")
                    }
                    html = text
                    pages[evidence.sourceURL] = text
                }
                let observed: [Decimal]
                if evidence.sourceFormat == .schemaOrg {
                    observed = try structuredPrices(in: html, productName: evidence.sourceProductName ?? "")
                } else {
                    observed = try listedPrices(in: html, plan: evidence.plan)
                }
                guard observed == evidence.observedPricesUSD.sorted() else {
                    throw CatalogError.invalid("Listed prices changed: \(observed.map(\.usdLabel).joined(separator: ", ")). Recheck the plan, discount and evidence date.")
                }
                let status = evidence.review == .provisional ? "PROVISIONAL" : "MATCH"
                print("\(status): \(offer.id) — \(evidence.calculationDescription)")
            } catch { failures.append("\(offer.id): \(error)") }
        }
        guard failures.isEmpty else { throw CatalogError.invalid(failures.joined(separator: "\n")) }
        print("Reference prices match their recorded observations. Provisional selections still require confirmation; no files were changed.")
    }
}
