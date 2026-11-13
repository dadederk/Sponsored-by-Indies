import Foundation

/// A reproducible reference price, not a promise of an App Store checkout price.
/// Keep all matching prices so identical plan names cannot hide an ambiguity.
struct SavingEstimate: Decodable {
    enum Period: String, Decodable { case year, lifetime, oneTime }
    enum Review: String, Decodable { case unambiguous, provisional }
    enum SourceFormat: String, Decodable { case appStore, schemaOrg }

    var regularPriceUSD: Decimal
    var discountPercent: Int
    var plan: String
    var period: Period
    var discountedPeriods: Int
    var currency: String
    var storefront: String
    var observedPricesUSD: [Decimal]
    var review: Review
    var verifiedOn: String
    var sourceURL: String
    var sourceFormat: SourceFormat? = nil
    var sourceProductName: String? = nil

    /// Round savings down to cents rather than overstate a fractional-cent discount.
    /// This is an estimate; the store's eligible checkout remains authoritative.
    var amountUSD: Decimal {
        var raw = regularPriceUSD * Decimal(discountPercent) / 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 2, .down)
        return rounded
    }

    var referencePriceLabel: String {
        switch period {
        case .year: "\(regularPriceUSD.usdLabel) per year"
        case .lifetime: "\(regularPriceUSD.usdLabel) for lifetime access"
        case .oneTime: "\(regularPriceUSD.usdLabel) one-time purchase"
        }
    }

    var calculationDescription: String {
        let duration = switch period {
        case .year: "first year"
        case .lifetime: "lifetime purchase"
        case .oneTime: "one-time purchase"
        }
        return "\(plan): \(regularPriceUSD.usdLabel) × \(discountPercent)% = \(amountUSD.usdLabel) potential saving (\(duration))."
    }
}

extension Decimal {
    var usdLabel: String {
        "US" + formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
    }
}

struct BundleValue {
    var offers: [Offer]
    var explanation: String
    var totalUSD: Decimal { offers.reduce(0) { $0 + ($1.savingEstimate?.amountUSD ?? 0) } }
    var amountLabel: String {
        "US$" + totalUSD.formatted(.number.precision(.fractionLength(0)).rounded(rule: .down).locale(Locale(identifier: "en_US")))
    }
    var verifiedOn: String { offers.compactMap { $0.savingEstimate?.verifiedOn }.min() ?? "" }
}

extension Catalog {
    func offersRequiringPriceChecks(on date: Date) -> [Offer] {
        let today = date.formatted(Edition.dayStyle)
        let currentEditions = Set(editions.filter { $0.endDate >= today }.map(\.id))
        return offers.filter {
            $0.publicationApproved && $0.savingEstimate != nil && currentEditions.contains($0.editionID)
        }
    }

    func bundleValue(for edition: Edition) -> BundleValue? {
        guard let summary = edition.valueSummary else { return nil }
        let byID = Dictionary(uniqueKeysWithValues: visibleOffers(for: edition).map { ($0.id, $0) })
        return BundleValue(offers: summary.offerIDs.compactMap { byID[$0] }, explanation: summary.explanation)
    }

    /// Builds are offline and deterministic. Refresh the evidence explicitly;
    /// current/upcoming editions must not quietly keep using old reference prices.
    func validatePriceFreshness(on date: Date, daysNotice: Int = 0) throws {
        let today = date.formatted(Edition.dayStyle)
        let startOfDay = try Date(today, strategy: Edition.dayStyle)
        for offer in offersRequiringPriceChecks(on: date) {
            guard let evidence = offer.savingEstimate else { continue }
            let checked = try Date(evidence.verifiedOn, strategy: Edition.dayStyle)
            let age = Int(startOfDay.timeIntervalSince(checked) / 86_400)
            guard evidence.verifiedOn <= today, age < 31 else {
                throw CatalogError.invalid("Price evidence for \(offer.id) is future-dated or over 30 days old. Recheck the US reference price.")
            }
            guard age < 31 - daysNotice else {
                throw CatalogError.invalid("Price evidence for \(offer.id) expires in \(31 - age) day(s). Review the source and refresh the evidence before the next publication deadline.")
            }
        }
    }
}
