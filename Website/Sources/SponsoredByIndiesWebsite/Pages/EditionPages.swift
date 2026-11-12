import Ignite

extension Pages {
    func editionPage(_ edition: Edition, asConferenceHome: Bool = false) -> MarketingPage {
        let conference = catalog.conference(for: edition)
        let path = asConferenceHome ? conference.path : edition.path(in: catalog)
        let otherEditions = catalog.editions(for: conference).filter { $0.id != edition.id }
        let people = catalog.visibleParticipations(for: edition)
        let offers = catalog.visibleOffers(for: edition)
        return MarketingPage(
            path: path, title: "\(conference.name) \(edition.label)", description: edition.introduction,
            canonicalPath: edition.path(in: catalog)
        ) {
            if asConferenceHome {
                Components.breadcrumb([("Conferences", "/conferences/"), ("\(conference.name) \(edition.label)", nil)])
            } else {
                Components.breadcrumb([("Conferences", "/conferences/"), (conference.name, conference.path), (edition.label, nil)])
            }
            Tag("section") {
                Section {
                    Components.eyebrow(edition.status)
                    Text("\(escaped(conference.name)) \(escaped(edition.label))").font(.title1)
                    Text {
                        escaped(edition.dateLabel) + " · "
                        Span(escaped(conference.location)).class("conference-location")
                    }
                    Text(escaped(conference.description))
                    Text(escaped(edition.introduction)).class("lead")
                    Section {
                        Components.button("Conference website", href: conference.websiteURL)
                    }.class("actions")
                }.class("container", "section-space")
            }.class("conference-panel").attribute("style", conference.identityStyle)
            Tag("nav") {
                Link("The bundle", target: "#bundle")
                if !people.isEmpty { Link("The makers", target: "#makers") }
                Link("Getting access", target: "#access")
                Link("The value", target: "#value")
                if !otherEditions.isEmpty { Link("Other editions", target: "#other-editions") }
            }.class("container", "edition-nav").aria(.label, "This edition")
            Tag("section") {
                Components.heading("Included with", "your ticket.", id: "bundle-title")
                if offers.isEmpty {
                    Section {
                        Text("Good things are taking shape.").font(.title3)
                        Text(
                            "We’re putting together this edition’s contributions. Confirmed products, exact discounts, and offer terms will appear here when ready."
                        )
                        Link("Check attendee access", target: "#access")
                    }.class("panel")
                } else {
                    Grid(offers, alignment: .top, spacing: .none) { offer in
                        Components.offerCard(offer, indie: catalog.indie(withID: offer.indieID))
                    }.columns(2).class("g-3")
                }
            }.id("bundle").class("container", "section-space").aria(.labelledBy, "bundle-title")
            if !people.isEmpty {
                Tag("section") {
                    Components.heading("Meet the", "makers.", id: "makers-title")
                    Grid(people, alignment: .top, spacing: .none) { participation in
                        Components.indieCard(catalog.indie(withID: participation.indieID), participation: participation)
                    }.columns(2).class("g-3")
                }.id("makers").class("container", "section-space").aria(.labelledBy, "makers-title")
            }
            Tag("section") {
                Components.heading("Getting", "access.", id: "access-title")
                accessGuidance(edition)
            }.id("access").class("container", "section-space").aria(.labelledBy, "access-title")
            Tag("section") {
                if let summary = edition.valueSummary, !offers.isEmpty {
                    Components.heading("Save up to", summary.amountLabel, id: "value-title")
                    Text(escaped(summary.explanation))
                    Text("Verified \(escaped(summary.verifiedOn)). Individual offer terms apply.")
                } else {
                    Components.heading("The bundle’s", "value.", id: "value-title")
                    Text("We’ll share the maximum potential savings once the offers and their terms are confirmed.")
                }
                Text(
                    "Any “up to” total describes savings from using all compatible offers. Your own saving depends on what you’re eligible for and choose to redeem."
                )
                Components.disclosure(
                    "Do I need to use everything?",
                    text:
                        "No. Choose what’s useful to you. The maximum describes savings from compatible offers, rather than a guaranteed saving."
                )
            }.id("value").class("container", "section-space").aria(.labelledBy, "value-title")
            if !otherEditions.isEmpty {
                Tag("section") {
                    Components.heading("Other", "editions.", id: "other-editions-title")
                    List(otherEditions) { other in
                        ListItem {
                            Link("\(escaped(conference.name)) \(escaped(other.label))", target: other.path(in: catalog))
                            Text(escaped(other.dateLabel))
                        }
                    }.class("edition-list").attribute("style", conference.identityStyle)
                }.id("other-editions").class("container", "section-space").aria(.labelledBy, "other-editions-title")
            }
            if asConferenceHome {
                Section {
                    Link("Permanent link to \(escaped(conference.name)) \(escaped(edition.label))", target: edition.path(in: catalog))
                }.class("container", "edition-nav")
            }
        }
    }

    func accessGuidance(_ edition: Edition) -> some HTML {
        Group {
            Text(escaped(edition.accessIntroduction)).class("lead")
            if let url = edition.accessURL { Components.button("Open attendee access", href: url) }
            if edition.accessURL == nil {
                Text(
                    "There are no codes to claim here yet. Once delivery is agreed, we’ll explain where to find your offers and their redemption deadlines."
                )
            } else {
                Text("Use the attendee access link, then follow the instructions for your products.")
            }
            Components.disclosure(
                "Can every attendee take part?",
                text:
                    "That’s the aim: contributions available to every eligible attendee. Ticket eligibility and product restrictions will be published with the confirmed offers."
            )
            Components.disclosure(
                "Do all offers work in the same way?",
                text:
                    "Each indie chooses its own contribution. Redemption methods, eligibility, access periods, and expiry dates may differ. Check each offer’s terms."
            )
            for offer in catalog.visibleOffers(for: edition) {
                Components.disclosure("Redeeming \(offer.productName)", text: offer.redemptionInstructions + " " + offer.terms)
            }
        }
    }

    func accessPage(_ edition: Edition) -> MarketingPage {
        let conference = catalog.conference(for: edition)
        let path = edition.path(in: catalog)
        return MarketingPage(
            path: path + "access/", title: "Attendee access · \(conference.name) \(edition.label)", description: edition.accessIntroduction,
            isIndexable: false
        ) {
            Components.breadcrumb([("Conferences", "/conferences/"), (conference.name + " " + edition.label, path), ("Access", nil)])
            Tag("section") {
                Components.title("Getting", emphasis: "access.").id("access-title")
                Text("For \(escaped(conference.name)) \(escaped(edition.label)) ticket holders.")
            }.class("container", "page-intro")
            Tag("section") {
                Section {
                    accessGuidance(edition)
                    Components.button("Back to the bundle", href: path + "#bundle", style: .secondary)
                }.class("reading-width")
            }.class("container", "section-space").aria(.labelledBy, "access-title")
        }
    }

}
