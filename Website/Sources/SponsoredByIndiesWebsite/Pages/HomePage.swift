import Foundation
import Ignite

extension Pages {
    var home: MarketingPage {
        MarketingPage(
            path: "/", title: "Indie bundles for Swift & iOS conferences",
            description:
                "Indie apps, games, books, courses, tools… Free products and discounts for attendees of iOS, Swift and Apple platform developer conferences."
        ) {
            Section {
                Grid(alignment: .top, spacing: .none) {
                    homeIntroduction
                    nextEdition
                }.columns(1).class("home-feature-grid", "row-cols-lg-2")
            }.class("container", "hero")
            howItWorks
            audienceBenefits
            Tag("section") {
                Section {
                    Text("Behind every indie project, people who care.")
                    Text("Behind every conference, people who bring us together.")
                    Components.title("Around both,", emphasis: "a community.", level: .title2).id(
                        "community-title")
                }.class("container", "reading-width")
            }.class("manifesto").aria(.labelledBy, "community-title")
        }
    }

    var homeIntroduction: some HTML {
        Tag("section") {
            Components.title("Good conferences.", emphasis: "A little extra.").id("home-title")
            Text("Hello. For those of us who think different. Indie bundles for iOS, Swift and Apple developer conferences.")
                .class("lead")
            Text(
                "Apps, games, books, courses, tools… Free products and discounts from indies connected to your conference, included with your ticket."
            )
            Section {
                Components.button("Find your conference", href: "/conferences/")
                Tag("nav") {
                    Link("How it works", target: "#how-it-works")
                    Link("What’s in it for you?", target: "#benefits-title")
                }.class("actions").margin(.top, 0).frame(maxWidth: .percent(100%)).aria(
                    .label, "On this page")
            }.class("actions")
        }.aria(.labelledBy, "home-title")
    }

    var nextEdition: some HTML {
        let featured = catalog.nextEdition(on: date)
        return Tag("section") {
            Components.heading("Our next", "edition.", id: "next-edition-title")
            for edition in catalog.editionsByDate {
                let card = Section {
                    Components.conferenceCard(
                        catalog.conference(for: edition), edition: edition, catalog: catalog)
                }
                .attribute("data-next-edition", escaped(edition.id))
                .attribute("data-start-date", edition.startDate)
                .attribute("data-end-date", edition.endDate)
                if edition.id == featured?.id { card } else { card.attribute("hidden") }
            }
            let empty = Text(
                "More editions are on the way. Explore our conferences and their bundles in the meantime."
            ).id("next-edition-empty")
            if featured == nil { empty } else { empty.attribute("hidden") }
            Section {
                Link("All conferences", target: "/conferences/")
            }.class("actions")
            Script(file: "/next-edition.mjs").attribute("type", "module")
        }.id("next-edition").aria(.labelledBy, "next-edition-title")
    }

    var howItWorks: some HTML {
        Tag("section") {
            Section {
                Components.heading("How it", "works.", id: "how-title")
                List {
                    ListItem {
                        Text("Connected to the conference.").font(.title3)
                        Text(
                            "Past speakers, current speakers, attendees. Indies with a reason to give a little back."
                        )
                    }
                    ListItem {
                        Text("A contribution of their own.").font(.title3)
                        Text(
                            "Each maker chooses what to share: a free product, a discount, or access to something useful."
                        )
                    }
                    ListItem {
                        Text("One more thing… for every attendee.").font(.title3)
                        Text(
                            "Your edition’s page brings the bundle together and explains how ticket holders get access."
                        )
                    }
                }.listMarkerStyle(.ordered).class("steps")
            }.class("container", "section-space")
        }.id("how-it-works").class("tinted-section").aria(.labelledBy, "how-title")
    }

    var audienceBenefits: some HTML {
        Tag("section") {
            Components.heading("Small contributions.", "Shared joy.", id: "benefits-title")
            Grid(spacing: .none) {
                Components.audienceBenefitCard(
                    "For attendees",
                    introduction:
                        "Discover useful indie products alongside the talks, conversations, and friendships you came for.",
                    benefits: [
                        "Free products and discounts included with your ticket.",
                        "Clear offer terms, access instructions, and deadlines.",
                        "Choose what’s useful to you; there’s no need to redeem everything.",
                    ],
                    actionLabel: "Find your conference", target: "/conferences/"
                )
                Components.audienceBenefitCard(
                    "For conference organisers",
                    introduction:
                        "Let indie makers add value to every ticket and give people another reason to book.",
                    benefits: [
                        "A tangible bundle to include in your ticket messaging.",
                        "An edition page with makers, offers, and maximum potential savings.",
                        "Help coordinating contributions and getting access to ticket holders.",
                    ],
                    actionLabel: "Bring this to your conference", target: "/participate/conferences/",
                    style: .secondary
                )
                Components.audienceBenefitCard(
                    "For independent makers",
                    introduction:
                        "Share a little of what you make with a conference community you care about.",
                    benefits: [
                        "Introduce your work to potential users in your community.",
                        "Choose the free access or discount that works for you.",
                        "Approve your profile and offer before they go live.",
                    ],
                    actionLabel: "Contribute as an indie", target: "/participate/indies/", style: .tertiary
                )
            }
            // Ignite puts semantic gutters on columns and fixes columns() at
            // the medium breakpoint. These row classes preserve gutters and the large-screen layout.
            .columns(1).class("g-3", "row-cols-lg-3")
        }.class("container", "section-space").aria(.labelledBy, "benefits-title")
    }
}
