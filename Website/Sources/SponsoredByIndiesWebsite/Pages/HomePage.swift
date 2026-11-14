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
            Components.audienceBenefits(for: [.attendees, .conferences, .indies])
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
            Components.title("Amazing conferences.", emphasis: "A little extra.").id("home-title")
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
            Components.heading("Our next", "bundle.", id: "next-edition-title")
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
            Script(file: "/next-edition.mjs").attribute("type", "module")
        }.id("next-edition").aria(.labelledBy, "next-edition-title")
    }

    var howItWorks: some HTML {
        Tag("section") {
            Section {
                Components.heading("How it", "works.", id: "how-title")
                Components.processSteps([
                    ("Connected to the conference.",
                     "Past speakers, current speakers, attendees, organisers… Indies connected to the conference choose what to share: a free product, a discount, or access to something useful."),
                    ("More value with every ticket.",
                     "We work with the conference to bring those contributions together as one bundle. Organisers get something extra to offer with every ticket and another reason for people to attend."),
                    ("One more thing… for every attendee.",
                     "Free products and discounts, included with your conference ticket. Your edition’s bundle page shows what’s included and how to get access."),
                ])
            }.class("container", "section-space")
        }.id("how-it-works").class("tinted-section").aria(.labelledBy, "how-title")
    }

}
