import Foundation
import Ignite

/// Registers the pages generated from the validated catalogue.
struct Pages {
    let catalog: Catalog
    var date: Date = .now
    var preview: Bool = false

    var all: [MarketingPage] {
        var pages = [directory, terms, participate, ConferenceInterest(catalog: catalog).page, IndieContribution(catalog: catalog, date: date).page,
                     showcase(preview: preview, asHostedPreview: true)]
        for conference in catalog.conferences {
            pages.append(conferencePage(conference))
            for edition in catalog.editions(for: conference) {
                pages.append(editionPage(edition))
                pages.append(accessPage(edition))
            }
        }
        return pages
    }

}
