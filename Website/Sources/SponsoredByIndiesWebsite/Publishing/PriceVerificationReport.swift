import Foundation

struct PriceVerificationReport {
    enum Status: String { case match = "MATCH", provisional = "PROVISIONAL", manual = "MANUAL", failed = "FAILED" }
    struct Entry {
        var offerID: String
        var status: Status
        var message: String
        var sourceURL: String
    }
    var entries: [Entry] = []

    var conclusion: String {
        let count = entries.filter { $0.status == .failed }.count
        return count == 0
            ? "Automatic checks passed; manual sources were not automatically verified. Provisional selections still need maker confirmation."
            : "\(count) price reference(s) need review. Publication runs separately."
    }

    var console: String {
        (entries.map { "\($0.status.rawValue): \($0.offerID) — \($0.message) Source: \($0.sourceURL)" }
         + [conclusion, "No content or check dates were changed."]).joined(separator: "\n")
    }

    var markdown: String {
        func cell(_ text: String) -> String {
            var result = text.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            for character in ["\\", "|", "`", "*", "_", "[", "]"] {
                result = result.replacingOccurrences(of: character, with: "\\" + character)
            }
            return result.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        }
        let rows = entries.map {
            "| \(cell($0.offerID)) | \($0.status.rawValue) | \(cell($0.message)) | \(cell($0.sourceURL)) |"
        }
        return (["## Public price sources", "", conclusion, "",
                 "| Offer | Result | Details | Source |", "| --- | --- | --- | --- |"] + rows
                + ["", "Manual sources retain the recorded review date and 30-day expiry. No content or check dates were changed.", ""]).joined(separator: "\n")
    }

    func requireSuccess() throws {
        let failures = entries.filter { $0.status == .failed }
        guard failures.isEmpty else {
            throw CatalogError.invalid(failures.map { "\($0.offerID): \($0.message) Source: \($0.sourceURL)" }.joined(separator: "\n"))
        }
    }
}
