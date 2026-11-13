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

    static func productCard(_ product: Offer, offers: [Offer], indie: Indie, participation: Participation) -> some HTML {
        return Tag("article") {
            Text {
                Link(target: product.productURL) {
                    if let icon = product.productIconPath {
                        Image(decorative: icon)
                            .frame(width: .px(DesignTokens.productIconSize), height: .px(DesignTokens.productIconSize))
                            .cornerRadius(DesignTokens.productIconRadius)
                    }
                    Span {
                        Span(escaped(product.productName)).class("product-card-title")
                        if let host = URL(string: product.productURL)?.host {
                            Span(escaped(host)).font(.small).fontWeight(.regular)
                                .foregroundStyle(.secondary).class("product-card-url")
                        }
                    }.class("product-card-name")
                }
            }.font(.title3).margin(0).class("product-card-heading")
            Text(escaped(product.description)).margin(0)
            // Safari otherwise removes list semantics when CSS hides the markers.
            List(offers) { offer in
                ListItem {
                    Badge(escaped(offer.benefit))
                        .foregroundStyle(Color(hex: DesignTokens.palette.blue))
                        .background(Color(hex: DesignTokens.palette.tint))
                        .fontWeight(.semibold)
                        .padding(.vertical, .small).padding(.horizontal, .medium)
                }
            }.class("product-card-benefits").attribute("role", "list")
            Section {
                Section {
                    Text {
                        Span(escaped(indie.name)).fontWeight(.semibold)
                        if let website = indie.websiteURL {
                            Span {
                                " · "
                                Link(escaped(indie.company ?? "Website"), target: website)
                            }
                        } else if let company = indie.company {
                            Span(" · " + escaped(company))
                        }
                    }.font(.small).margin(0)
                    productTerms(product, offers: offers)
                }.class("product-card-byline")
                if let connection = participation.connection {
                    Text(escaped(connection)).font(.small).margin(0)
                }
                if let quote = participation.quote {
                    Quote { Text("“" + escaped(quote) + "”").font(.small).margin(0) }
                        .margin(.top, .small).margin(.bottom, 0)
                }
                for social in indie.socials { Link(escaped(social.label), target: social.url).font(.small) }
            }.foregroundStyle(.secondary).class("product-card-maker")
        }.class("panel", "product-card")
    }

    private static func productTerms(_ product: Offer, offers: [Offer]) -> some HTML {
        let sharedInstructions = Set(offers.map(\.redemptionInstructions)).count == 1 ? offers.first?.redemptionInstructions : nil
        return Tag("details") {
            Tag("summary") {
                "Offer terms"
                Span(" for " + escaped(product.productName)).class("visually-hidden")
            }.fontWeight(.regular)
            for offer in offers {
                Section {
                    Text(escaped(offer.benefit)).fontWeight(.semibold).margin(.bottom, 0)
                    if let estimate = offer.savingEstimate {
                        Text {
                            Span("US reference price: ").fontWeight(.semibold)
                            Link(escaped(estimate.referencePriceLabel), target: estimate.sourceURL)
                            Span(" · " + escaped(estimate.plan))
                        }.margin(.bottom, 0)
                    }
                    Text(escaped(offer.terms)).margin(.bottom, 0)
                    if sharedInstructions == nil { Text(escaped(offer.redemptionInstructions)) }
                }.margin(.bottom, .small)
            }
            // Shared redemption instructions only need to appear once per app.
            if let sharedInstructions {
                Text {
                    Span("Redemption: ").fontWeight(.semibold)
                    escaped(sharedInstructions)
                }.margin(.bottom, 0)
            }
        }.font(.small).class("product-card-terms")
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
