import Ignite

extension Components {
    static func offerSharing(_ product: Offer, bundlePath: String) -> some InlineElement {
        cardSharing(name: product.productName, permalink: bundlePath + "#" + product.bundleAnchor,
                    subject: "this offer", context: " in this bundle")
    }

    static func projectSharing(_ project: Project, showcasePath: String) -> some InlineElement {
        cardSharing(name: project.name, permalink: showcasePath + "#" + project.bundleAnchor,
                    subject: "this project", context: "")
    }

    private static func cardSharing(name: String, permalink: String, subject: String, context: String) -> some InlineElement {
        Span {
            Link(target: escaped(permalink)) {
                Span("#").class("title-accent").aria(.hidden, "true")
                Span("Link to " + subject + " for " + escaped(name)).class("visually-hidden")
            }.class("offer-share-control").attribute("title", "Link to " + subject)
                .attribute("data-offer-permalink", "true")
            Button {
                Span("#").class("title-accent").aria(.hidden, "true")
                    .attribute("data-copy-icon", "true")
                Image(systemName: "check2", description: "").aria(.hidden, "true")
                    .attribute("data-copied-icon", "true").attribute("hidden")
                Span("Copy link to " + escaped(name) + context).class("visually-hidden")
            }.role(.none).class("offer-share-control")
                .attribute("title", "Copy link to " + subject)
                .attribute("data-offer-copy", "true").attribute("hidden")
            Span().attribute("role", "status").attribute("aria-atomic", "true")
                .attribute("data-offer-copy-status", "true").class("visually-hidden")
        }.class("offer-share-action")
    }

    static var offerSharingFallback: some HTML {
        sharingFallback(label: "Link to this offer")
    }

    static func sharingFallback(label: String) -> some HTML {
        Section {
            Tag("input").attribute("type", "text").attribute("readonly")
                .aria(.label, escaped(label)).class("form-control")
        }.attribute("data-offer-copy-fallback", "true").attribute("hidden")
    }
}
