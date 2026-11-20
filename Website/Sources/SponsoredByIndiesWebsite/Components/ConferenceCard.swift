import Foundation
import Ignite

extension Components {
    static func conferenceCard(
        _ conference: Conference, edition: Edition?, catalog: Catalog,
        headingLevel: Font.Style = .title3
    )
        -> some HTML
    {
        Tag("article") {
            Section {
                Text { Link(escaped(conference.name), target: edition?.path(in: catalog) ?? conference.path) }.font(headingLevel)
                Text { conferenceLocation(conference.location) }
                if let edition { Text(escaped(edition.dateLabel)) }
            }.class("conference-panel").attribute("style", conference.identityStyle)
            Section {
                if let edition {
                    Text("The \(escaped(edition.label)) indie bundle").font(.title3)
                    Text(escaped(edition.introduction))
                    button("See the \(conference.name) \(edition.label) bundle", href: edition.path(in: catalog))
                } else {
                    conferenceDescription(conference)
                    button("See the \(conference.name) bundle", href: conference.path)
                }
            }.class("panel")
        }.class("conference-card")
    }

    static func conferenceLocation(_ location: String) -> some InlineElement {
        Span(escaped(location))
            .font(.system(size: .rem(DesignTokens.conferenceLocationSize), weight: .bold))
            .class("conference-location")
    }

    static func conferenceDescription(_ conference: Conference) -> Text {
        guard let link = conference.descriptionLink,
              let range = conference.description.range(of: link.text) else {
            return Text(escaped(conference.description))
        }
        return Text {
            escaped(String(conference.description[..<range.lowerBound]))
            Link(escaped(link.text), target: escaped(link.url))
            escaped(String(conference.description[range.upperBound...]))
        }
    }
}
