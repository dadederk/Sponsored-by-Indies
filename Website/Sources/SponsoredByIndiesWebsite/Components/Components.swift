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

    static func brand(assetVersion: String, identity: SiteIdentity = .sponsored) -> some InlineElement {
        Span {
            Image(decorative: "/logo.svg?v=shared-imprint-01-\(assetVersion)").class("brand-mark")
            Span {
                if identity == .sponsored { Span("Sponsored").class("brand-sponsored") }
                Span {
                    Span("by ").class("brand-by")
                    Span(SiteIdentity.wordmarkName).class("title-accent", "brand-name")
                }.class("brand-signature")
            }.class("brand-wordmark")
        }.foregroundStyle(Color(hex: DesignTokens.palette.blue))
    }

    static func header(assetVersion: String, identity: SiteIdentity = .sponsored, preview: Bool = false, homePath: String = "/", sponsoredRoot: String? = nil) -> some HTML {
        Group {
            Link("Skip to content", target: "#main").class("skip-link")
            Tag("header") {
                Link(brand(assetVersion: assetVersion, identity: identity), target: homePath).class("brand").aria(.label, identity.name + ". Home")
                Tag("nav") {
                    if identity == .sponsored {
                        Link("All Conferences", target: "/conferences/")
                        Link("Get involved", target: "/participate/")
                    } else {
                        Link("Sponsored by Indies", target: (sponsoredRoot ?? SiteIdentity.sponsored.baseURL(preview: preview)) + "/")
                    }
                }.aria(.label, "Main navigation")
            }.class("container", "site-header")
        }
    }

    static func footer(assetVersion: String, identity: SiteIdentity = .sponsored, preview: Bool = false, homePath: String = "/", sponsoredRoot: String? = nil) -> some HTML {
        Tag("footer") {
            HStack(alignment: .center, spacing: .none) {
                Link(brand(assetVersion: assetVersion, identity: identity), target: homePath).class("brand").aria(.label, identity.name + ". Home")
                Section {
                    Text(identity.headline)
                    Text(identity.emphasis)
                }
            }.class("footer-identity")
            Text {
                "Built in Swift with "
                Link("Ignite.", target: "https://github.com/Ignite-Swift/Ignite")
            }
            .foregroundStyle(.secondary)
            Tag("nav") {
                if identity == .showcase {
                    Link("Sponsored by Indies", target: (sponsoredRoot ?? SiteIdentity.sponsored.baseURL(preview: preview)) + "/")
                } else {
                    Link("For conferences", target: "/participate/conferences/")
                    Link("For indies", target: "/participate/indies/")
                    Link("By Indies", target: SiteIdentity.showcase.baseURL(preview: preview) + "/")
                }
                Link("Terms &amp; conditions", target: sponsoredRoot.map { $0 + "/terms/" } ?? identity.sponsoredLink("/terms/", preview: preview))
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

    static func productCard(_ product: Offer, offers: [Offer], indie: Indie, participation: Participation, bundlePath: String) -> some HTML {
        // Hex-encoded IDs stay unique and safe as selectors even when editorial IDs contain punctuation.
        let termsID = "offer-terms-" + product.id.utf8.map { String(("0" + String($0, radix: 16)).suffix(2)) }.joined()
        return Tag("article") {
            HStack(alignment: .top, spacing: .small) {
                projectHeading(product.productName, url: product.productURL, icon: product.productIconPath)
                offerSharing(product, bundlePath: bundlePath)
            }.class("product-card-header")
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
                if let quote = participation.quote {
                    Quote {
                        Text {
                            "“" + escaped(quote) + "”"
                            if let attribution = participation.quoteAttribution {
                                Span(" — ")
                                Link(escaped(attribution.name), target: escaped(attribution.sourceURL))
                            }
                        }.font(.small).margin(0)
                    }.margin(.top, 0).margin(.bottom, .small)
                }
                Text {
                    if let people = indie.people {
                        Span {
                            InlineForEach(Array(people.enumerated())) { index, person in
                                if index > 0 { Span(" &amp; ") }
                                if let url = person.websiteURL {
                                    Span { Link(escaped(person.name), target: escaped(url)) }
                                }
                                if person.websiteURL == nil {
                                    Span(escaped(person.name))
                                }
                            }
                        }.fontWeight(.semibold)
                    } else {
                        Span(escaped(indie.name)).fontWeight(.semibold)
                    }
                    if let website = indie.websiteURL {
                        Span {
                            " · "
                            Link(escaped(indie.company ?? "Website"), target: website)
                        }
                    } else if let company = indie.company {
                        Span(" · " + escaped(company))
                    }
                    if let connection = participation.connection {
                        Span(" · " + escaped(connection))
                    }
                    Span {
                        " · "
                        // Bootstrap's data API restores focus to this link when the modal closes.
                        Link(target: "#" + termsID) {
                            "Terms"
                            Span(" for " + escaped(product.productName)).class("visually-hidden")
                        }.attribute("data-bs-toggle", "modal")
                            .class("offer-terms-link")
                            .aria(.hasPopup, "dialog").aria(.controls, termsID)
                    }.attribute("data-offer-terms-trigger", "true").attribute("hidden")
                }.font(.small).margin(0)
                for social in indie.socials { Link(escaped(social.label), target: social.url).font(.small) }
                productTerms(product, offers: offers, id: termsID)
                offerSharingFallback
            }.foregroundStyle(.secondary).class("product-card-maker")
        }.class("panel", "product-card")
    }

    private static func productTerms(_ product: Offer, offers: [Offer], id: String) -> some HTML {
        Group {
            Modal(id: id) {
                productTermsContent(offers)
            } header: {
                Text("Offer terms for " + escaped(product.productName))
                    .font(.title3).margin(0).id(id + "-title")
                Button().role(.close).attribute("data-bs-dismiss", "modal")
            }
            .size(.large).scrollableContent(true).animated(false)
            Tag("details") {
                Tag("summary") { "Offer terms for " + escaped(product.productName) }
                productTermsContent(offers)
            }.id(id + "-fallback").attribute("data-offer-terms-fallback", "true").font(.small)
        }
    }

    private static func productTermsContent(_ offers: [Offer]) -> some HTML {
        let sharedInstructions = Set(offers.map(\.redemptionInstructions)).count == 1 ? offers.first?.redemptionInstructions : nil
        return Group {
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
        }
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

}
