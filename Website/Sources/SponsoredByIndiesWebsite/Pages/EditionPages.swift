import Ignite

extension Pages {
    func editionPage(_ edition: Edition, asConferenceHome: Bool = false) -> MarketingPage {
        let conference = catalog.conference(for: edition)
        let path = asConferenceHome ? conference.path : edition.path(in: catalog)
        let otherEditions = catalog.editions(for: conference).filter { $0.id != edition.id }
        let people = catalog.visibleParticipations(for: edition)
        let offers = catalog.visibleOffers(for: edition)
        let products = catalog.visibleProductContributions(for: edition)
        return MarketingPage(
            path: path, title: "\(conference.name) \(edition.label)", description: edition.introduction,
            canonicalPath: edition.path(in: catalog), bundleArtwork: BundleArtwork(conference: conference, edition: edition)
        ) {
            if asConferenceHome {
                Components.breadcrumb([("Conferences", "/conferences/"), ("\(conference.name) \(edition.label)", nil)])
            } else {
                Components.breadcrumb([("Conferences", "/conferences/"), (conference.name, conference.path), (edition.label, nil)])
            }
            Tag("section") {
                Section {
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
                Link("The value", target: "#value")
                Link("Getting access", target: "#access")
                if !otherEditions.isEmpty { Link("Other editions", target: "#other-editions") }
            }.class("container", "edition-nav").aria(.label, "This edition")
            Tag("section") {
                Components.heading("Included with your", "\(conference.name) ticket.", id: "bundle-title")
                if offers.isEmpty {
                    Section {
                        Text("Good things are taking shape.").font(.title3)
                        Text(
                            "We’re putting together this edition’s contributions. Confirmed products, exact discounts, and offer terms will appear here when ready."
                        )
                        Link("Check attendee access", target: "#access")
                    }.class("panel")
                } else {
                    Grid(products, alignment: .top, spacing: .none) { contribution in
                        Section {
                            if let participation = people.first(where: { $0.indieID == contribution.product.indieID }) {
                                Components.productCard(
                                    contribution.product, offers: contribution.offers,
                                    indie: catalog.indie(withID: contribution.product.indieID), participation: participation,
                                    bundlePath: edition.path(in: catalog))
                            }
                        }
                        .id(contribution.product.bundleAnchor).attribute("data-offer-sharing", "true")
                    }.columns(2).class("g-3", "product-grid")
                    Script(file: "/offer-terms.mjs").attribute("type", "module")
                    Script(file: "/offer-sharing.mjs?v=\(DesignTokens.version)").attribute("type", "module")
                }
            }.id("bundle").class("container", "section-space").aria(.labelledBy, "bundle-title")
            Tag("section") {
                if let summary = catalog.bundleValue(for: edition), !offers.isEmpty {
                    Components.heading("Potential value:", summary.amountLabel, id: "value-title")
                    Text("The estimate reflects compatible offers in the current bundle. Your saving depends on eligibility and which offers you choose. US prices in USD are our baseline; local prices may vary.")
                    Tag("details") {
                        Tag("summary") { "How we estimate the bundle’s value" }
                        Text(escaped(summary.explanation))
                        Text("Prices checked \(escaped(summary.verifiedOn)). Individual offer terms apply.")
                        for offer in summary.offers {
                            if let estimate = offer.savingEstimate {
                                Section {
                                    Text(escaped(offer.productName + " — " + estimate.calculationDescription))
                                    Text { Link("US price reference: " + escaped(offer.productName), target: estimate.sourceURL) }
                                }
                            }
                        }
                        Text("Savings are rounded down to cents before adding compatible offers. The headline then rounds down to whole US dollars. Final checkout prices may differ.")
                    }
                } else {
                    Components.heading("The bundle’s", "value.", id: "value-title")
                    Text("We’ll share the maximum potential savings once the offers and their terms are confirmed.")
                }
                if let note = edition.bundleNote {
                    Text {
                        escaped(note) + " If you’d like to share something from your indie project, "
                        Link("get in touch", target: "/participate/indies/")
                        "."
                    }
                }
            }.id("value").class("container", "section-space").aria(.labelledBy, "value-title")
            Tag("section") {
                Components.heading("Getting", "access.", id: "access-title")
                accessGuidance(edition)
            }.id("access").class("container", "section-space").aria(.labelledBy, "access-title")
            if !offers.isEmpty { Components.attendeeThanks }
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
            Text("Each product card includes its offer terms and redemption guidance.")
        }
    }

    func accessPage(_ edition: Edition) -> MarketingPage {
        let conference = catalog.conference(for: edition)
        let path = edition.path(in: catalog)
        return MarketingPage(
            path: path + "access/", title: "Attendee access · \(conference.name) \(edition.label)", description: edition.accessIntroduction,
            isIndexable: false, bundleArtwork: BundleArtwork(conference: conference, edition: edition)
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
            if !catalog.visibleOffers(for: edition).isEmpty { Components.attendeeThanks }
        }
    }

}
