import Ignite

extension Pages {
    var directory: MarketingPage {
        let nextEdition = catalog.nextEdition(on: date)
        let nextConference = nextEdition.map(catalog.conference(for:))
        let remainingConferences = catalog.conferences.filter { $0.id != nextConference?.id }
        return MarketingPage(path: "/conferences/", title: "Conferences", description: "Find iOS, Swift and Apple platform developer conferences and explore their indie bundles.") {
            Components.breadcrumb([("Home", "/"), ("Conferences", nil)])
            Tag("section") {
                Components.title("Find your", emphasis: "conference.")
                Text("Explore indie bundles for iOS, Swift and Apple developer conferences. Each edition has its own makers, contributions, and story.").class("lead")
            }.class("container", "page-intro")
            Section {
                if let nextEdition, let nextConference {
                    Components.conferenceCard(
                        nextConference, edition: nextEdition, catalog: catalog, headingLevel: .title2)
                        .class("conference-card-featured")
                }
                if !remainingConferences.isEmpty {
                    Tag("div") {
                        for conference in remainingConferences {
                            Components.conferenceCard(
                                conference, edition: catalog.featuredEdition(for: conference, on: date),
                                catalog: catalog, headingLevel: .title2)
                        }
                    }.class("conference-card-grid")
                }
            }.class("container", "section-space", "conference-directory")
            Components.audienceBenefits(for: [.conferences, .indies], title: "Get", emphasis: "involved.")
            Components.attendeeThanks
        }
    }

    func conferencePage(_ conference: Conference) -> MarketingPage {
        if let edition = catalog.featuredEdition(for: conference, on: date) {
            return editionPage(edition, asConferenceHome: true)
        }
        return MarketingPage(path: conference.path, title: conference.name, description: conference.description) {
            Components.breadcrumb([("Conferences", "/conferences/"), (conference.name, nil)])
            Tag("section") {
                Section {
                    Text(escaped(conference.name)).font(.title1)
                    Text { Components.conferenceLocation(conference.location) }
                    Components.conferenceDescription(conference).class("lead")
                    Link("Visit the conference website", target: conference.websiteURL)
                }.class("container", "section-space")
            }.class("conference-panel").attribute("style", conference.identityStyle)
            Section {
                Text("This conference’s first indie bundle is being arranged. Edition details will appear here when ready.")
            }.class("container", "section-space")
        }
    }

}
