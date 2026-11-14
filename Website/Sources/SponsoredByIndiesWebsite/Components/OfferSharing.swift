import Ignite

extension Components {
    static func offerSharing(_ product: Offer, bundlePath: String) -> some InlineElement {
        Span {
            Link(target: escaped(bundlePath + "#" + product.bundleAnchor)) {
                Span("#").class("title-accent").aria(.hidden, "true")
                Span("Link to this offer for " + escaped(product.productName)).class("visually-hidden")
            }.class("offer-share-control").attribute("title", "Link to this offer")
                .attribute("data-offer-permalink", "true")
            Button {
                Span("#").class("title-accent").aria(.hidden, "true")
                    .attribute("data-copy-icon", "true")
                Image(systemName: "check2", description: "").aria(.hidden, "true")
                    .attribute("data-copied-icon", "true").attribute("hidden")
                Span("Copy link to " + escaped(product.productName) + " in this bundle").class("visually-hidden")
            }.role(.none).class("offer-share-control")
                .attribute("title", "Copy link to this offer")
                .attribute("data-offer-copy", "true").attribute("hidden")
            Span().attribute("role", "status").attribute("aria-atomic", "true")
                .attribute("data-offer-copy-status", "true").class("visually-hidden")
        }.class("offer-share-action")
    }

    static var offerSharingFallback: some HTML {
        Section {
            Tag("input").attribute("type", "text").attribute("readonly")
                .aria(.label, "Link to this offer").class("form-control")
        }.attribute("data-offer-copy-fallback", "true").attribute("hidden")
    }
}
