import Ignite

extension Components {
    static var attendeeThanks: some HTML {
        Tag("section") {
            Section {
                heading("A little thanks.", "A big difference.", id: "support-indies-title")
                    .margin(.top, 0).margin(.bottom, .custom("var(--heading-gap)"))
                Text("If you discover something you enjoy, consider sharing the maker’s work or recommending it to a friend. For apps, an honest App Store rating or review after you’ve tried them can help too. Little gestures go a long way for indies.")
                    .margin(.bottom, 0)
            }.class("container", "reading-width")
        }.id("support-indies").class("manifesto")
            .padding(.vertical, .custom("var(--section-space)"))
            .aria(.labelledBy, "support-indies-title")
    }
}
