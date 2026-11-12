import Foundation
import Ignite

func escaped(_ value: String) -> String {
    value.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

enum Components {
    enum ButtonStyle: Equatable {
        case primary, secondary, tertiary
    }

    static func brand(assetVersion: String) -> some InlineElement {
        Span {
            Image(decorative: "/logo.svg?v=shared-imprint-01-\(assetVersion)").class("brand-mark")
            Span {
                Span("Sponsored by").class("brand-by")
                Span("Indies").class("brand-name")
            }.class("brand-wordmark")
        }
    }

    static func header(assetVersion: String) -> some HTML {
        Group {
            Link("Skip to content", target: "#main").class("skip-link")
            Tag("header") {
                Link(brand(assetVersion: assetVersion), target: "/").class("brand").aria(.label, "Sponsored by Indies. Home")
                Tag("nav") {
                    Link("Conferences", target: "/conferences/")
                    Link("Get involved", target: "/participate/")
                }.aria(.label, "Main navigation")
            }.class("container", "site-header")
        }
    }

    static func footer(assetVersion: String) -> some HTML {
        Tag("footer") {
            HStack(alignment: .center, spacing: .none) {
                Link(brand(assetVersion: assetVersion), target: "/").class("brand")
                Section {
                    Text("A little extra.")
                    Text("From your community.")
                }
            }.class("footer-identity")
            Text {
                "Built in Swift with "
                Link("Ignite.", target: "https://github.com/Ignite-Swift/Ignite")
            }
            .foregroundStyle(.secondary)
            Tag("nav") {
                Link("Conferences", target: "/conferences/")
                Link("For organisers", target: "/participate/conferences/")
                Link("For indies", target: "/participate/indies/")
                Link("Terms and conditions", target: "/terms/")
            }.aria(.label, "Footer navigation")
        }.class("container", "site-footer")
    }

    static func button(_ label: String, href: String, style: ButtonStyle = .primary) -> some InlineElement {
        let role: Role =
            switch style {
            case .primary: .primary
            case .secondary, .tertiary: .secondary
            }
        return Link(escaped(label), target: href).linkStyle(.button).role(role)
            .class(style == .tertiary ? ["btn-tertiary"] : [])
    }

    static func eyebrow(_ label: String) -> some HTML {
        Text(escaped(label)).class("eyebrow")
    }

    static func title(_ plain: String, emphasis: String, level: Font.Style = .title1) -> some HTML {
        Text {
            escaped(plain) + " "
            Span(escaped(emphasis)).class("title-accent")
        }.font(level)
    }

    static func breadcrumb(_ items: [(String, String?)]) -> some HTML {
        Tag("nav") {
            List(items) { label, path in
                ListItem {
                    if let path { Link(escaped(label), target: path) } else { Span(escaped(label)).aria(.current, "page") }
                }
            }.listMarkerStyle(.ordered).class("breadcrumb")
        }.class("container", "page-breadcrumb").aria(.label, "Breadcrumb")
    }

    static func heading(_ plain: String, _ emphasis: String, id: String) -> some HTML {
        title(plain, emphasis: emphasis, level: .title2).id(id)
    }

    static func conferenceCard(_ conference: Conference, edition: Edition?, catalog: Catalog, headingLevel: Font.Style = .title3)
        -> some HTML
    {
        Tag("article") {
            Section {
                eyebrow(edition?.status ?? "Participating conference")
                Text { Link(escaped(conference.name), target: edition?.path(in: catalog) ?? conference.path) }.font(headingLevel)
                Text(escaped(conference.location)).class("conference-location")
                if let edition { Text(escaped(edition.dateLabel)) }
            }.class("conference-panel").attribute("style", conference.identityStyle)
            Section {
                if let edition {
                    Text("The \(escaped(edition.label)) indie bundle").font(.title3)
                    Text(escaped(edition.introduction))
                    button("See the \(conference.name) \(edition.label) bundle", href: edition.path(in: catalog))
                } else {
                    Text(escaped(conference.description))
                    button("See the \(conference.name) bundle", href: conference.path)
                }
            }.class("panel")
        }.class("conference-card")
    }

    static func indieCard(_ indie: Indie, participation: Participation) -> some HTML {
        Tag("article") {
            Text(escaped(indie.name)).font(.title3)
            if let company = indie.company { Text(escaped(company)) }
            if let connection = participation.connection { Text(escaped(connection)).foregroundStyle(.secondary) }
            if let quote = participation.quote { Quote { Text(escaped(quote)) } }
            if let website = indie.websiteURL { Link("Visit \(escaped(indie.name))’s website", target: website) }
            for social in indie.socials { Link(escaped(social.label), target: social.url) }
        }.class("panel")
    }

    static func offerCard(_ offer: Offer, indie: Indie) -> some HTML {
        Tag("article") {
            eyebrow("By \(indie.name)")
            Text { Link(escaped(offer.productName), target: offer.productURL) }.font(.title3)
            Text(escaped(offer.description))
            Text(escaped(offer.benefit)).fontWeight(.bold).foregroundStyle(Color(hex: DesignTokens.palette.accent))
            disclosure("Offer terms for \(offer.productName)", text: offer.terms)
        }.class("panel")
    }

    // Native details/summary supports keyboard and assistive technology without a script.
    static func disclosure(_ title: String, text: String) -> some HTML {
        Tag("details") {
            Tag("summary") { escaped(title) }
            Text(escaped(text))
        }
    }

    static func interestURL(_ contact: String, subject: String, body: String? = nil) -> String {
        guard var url = URLComponents(string: contact), url.scheme == "mailto" else { return contact }
        url.queryItems = [URLQueryItem(name: "subject", value: subject)]
        if let body { url.queryItems?.append(URLQueryItem(name: "body", value: body)) }
        return url.string ?? contact
    }

    static var joinCalls: some HTML {
        Tag("section") {
            heading("Small contributions.", "Shared joy.", id: "join-title")
            Grid(alignment: .top, spacing: .none) {
                Section {
                    Text("For conference organisers").font(.title3)
                    Text("Give attendees a bundle of useful indie products and another reason to book their ticket.")
                    button("Express conference interest", href: "/participate/conferences/", style: .secondary)
                }
                Section {
                    Text("For independent makers").font(.title3)
                    Text("Share an app, game, book, course, tool… with a conference community you care about.")
                    button("Contribute as an indie", href: "/participate/indies/", style: .tertiary)
                }
            }.columns(2).class("g-3")
            Text("See how the partnership works, or tell us what you’d like to contribute.").class("contact-note")
        }.class("container", "section-space", "join-section").aria(.labelledBy, "join-title")
    }
}
