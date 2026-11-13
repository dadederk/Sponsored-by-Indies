import Foundation

/// A read-only check of public US App Store listings. It never updates approved
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
                guard let url = URL(string: evidence.sourceURL), url.host == "apps.apple.com", url.path.hasPrefix("/us/app/") else {
                    throw CatalogError.invalid("Live checker supports US App Store references only.")
                }
                let html: String
                if let cached = pages[evidence.sourceURL] { html = cached }
                else {
                    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
                    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                          response.url?.host == "apps.apple.com", response.url?.path.hasPrefix("/us/app/") == true,
                          let text = String(data: data, encoding: .utf8) else {
                        throw CatalogError.invalid("Could not read a successful US App Store response.")
                    }
                    html = text
                    pages[evidence.sourceURL] = text
                }
                let observed = try listedPrices(in: html, plan: evidence.plan)
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
