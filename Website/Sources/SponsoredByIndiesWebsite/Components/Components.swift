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
            Image(decorative: "/\(ArtworkPaths.mark)?v=\(assetVersion)").class("brand-mark")
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
