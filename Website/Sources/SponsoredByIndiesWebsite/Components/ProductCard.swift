import Ignite

extension Components {
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
                            if let attribution = participation.quoteAttribution, (indie.people?.count ?? 1) > 1 {
                                Span(" – " + escaped(attribution.name))
                            }
                        }.font(.small).margin(0)
                    }
                }
                Section {
                    Text {
                        if let people = indie.people {
                            Span {
                                InlineForEach(Array(people.enumerated())) { index, person in
                                    if index > 0 { Span(" &amp; ") }
                                    if let url = person.websiteURL {
                                        Span { Link(escaped(person.creditName ?? person.name), target: escaped(url)) }
                                    }
                                    if person.websiteURL == nil {
                                        Span(escaped(person.creditName ?? person.name))
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
                }.class("product-card-footer")
            }.foregroundStyle(.secondary).class("product-card-maker")
        }.class("panel", "product-card")
            .padding(.bottom, .custom("var(--space-2)"))
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
            if offers.count > 1 {
                Text("Choose one offer:").fontWeight(.semibold).margin(.bottom, .small)
            }
            List(offers) { offer in
                ListItem {
                    Text(escaped(offer.benefit)).fontWeight(.semibold).margin(.bottom, 0)
                    if let estimate = offer.savingEstimate {
                        Text {
                            Span("Estimated price: ")
                            Span(escaped(estimate.offerPriceLabel)).fontWeight(.semibold)
                            Span(" · Save " + escaped(estimate.amountUSD.usdLabel) + " (\(estimate.discountPercent)%).")
                        }.margin(.bottom, 0)
                        Text {
                            Span("Regular US price: ")
                            Link(escaped(estimate.referencePriceLabel), target: estimate.sourceURL)
                            Span(" · " + escaped(estimate.plan))
                        }.margin(.bottom, 0)
                    }
                    Text(escaped(offer.terms)).margin(.bottom, 0)
                    if let renewal = offer.renewalDescription {
                        Text(escaped(renewal)).margin(.bottom, 0)
                    }
                    if sharedInstructions == nil {
                        Text {
                            Span("Redemption: ").fontWeight(.semibold)
                            escaped(offer.redemptionInstructions)
                        }.margin(.bottom, 0)
                    }
                }.margin(.bottom, .small)
            }.aria(.label, "Offer options").margin(.bottom, .small)
            // Shared redemption instructions only need to appear once per app.
            if let sharedInstructions {
                Text {
                    Span("Redemption: ").fontWeight(.semibold)
                    escaped(sharedInstructions)
                }.margin(.bottom, 0)
            }
        }
    }
}
