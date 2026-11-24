import Foundation

struct PressMention: Decodable {
    var label: String
    var url: String
    var publishedOn: String
    var quote: String? = nil
    var author: String? = nil

    var publicationDate: Date? { try? Date(publishedOn, strategy: Edition.dayStyle) }

    var dateLabel: String {
        // Date-only content keeps its calendar day regardless of the build machine's time zone.
        let style = Date.FormatStyle(timeZone: .gmt)
            .day().month(.wide).year().locale(Locale(identifier: "en_GB"))
        return publicationDate?.formatted(style) ?? publishedOn
    }
}
