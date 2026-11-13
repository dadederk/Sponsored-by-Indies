import Ignite

extension Components {
    enum Audience: String {
        case attendees, conferences, indies
    }

    static func audienceBenefits(
        for audiences: [Audience], title: String = "What’s in it", emphasis: String = "for you?"
    ) -> some HTML {
        Tag("section") {
            heading(title, emphasis, id: "benefits-title")
            audienceBenefitCards(for: audiences)
        }.class("container", "section-space").aria(.labelledBy, "benefits-title")
    }

    static func audienceBenefitCards(for audiences: [Audience], titleStyle: Font.Style = .title3) -> some HTML {
        Grid(audiences, spacing: .none) { audience in
            audienceBenefitCard(for: audience, titleStyle: titleStyle).id(audience.rawValue)
        }
        // Ignite fixes columns() at the medium breakpoint. Keep readable
        // card widths until large screens, using its generated grid classes.
        .columns(1).class("audience-cards", "g-3", audiences.count == 3 ? "row-cols-lg-3" : "row-cols-lg-2")
    }

    @HTMLBuilder
    private static func audienceBenefitCard(for audience: Audience, titleStyle: Font.Style) -> some HTML {
        switch audience {
        case .attendees:
            audienceBenefitCard(
                "For attendees",
                introduction:
                    "Discover useful indie products alongside the talks, conversations, and friendships you came for.",
                benefits: [
                    "Free products and discounts included with your ticket.",
                    "Clear offer terms, access instructions, and deadlines.",
                    "Choose what’s useful to you; there’s no need to redeem everything.",
                ],
                actionLabel: "Find your conference", target: "/conferences/", titleStyle: titleStyle
            )
        case .conferences:
            audienceBenefitCard(
                "For conference organisers",
                introduction:
                    "Give attendees a bundle of useful indie products and another reason to book their ticket.",
                benefits: [
                    "Free products and discounts to include with every ticket.",
                    "An edition page with makers, offers, and maximum potential savings.",
                    "Help coordinating contributions and getting access to ticket holders.",
                ],
                actionLabel: "Bring this to your conference", target: "/participate/conferences/",
                style: .secondary, titleStyle: titleStyle
            )
        case .indies:
            audienceBenefitCard(
                "For independent makers",
                introduction:
                    "Share your app, game, book, course, tool… with a conference community you care about.",
                benefits: [
                    "Introduce your work to potential users in your community.",
                    "Choose the free access or discount that works for you.",
                    "Approve your profile and offer before they go live.",
                ],
                actionLabel: "Contribute as an indie", target: "/participate/indies/", style: .tertiary,
                titleStyle: titleStyle
            )
        }
    }
}
