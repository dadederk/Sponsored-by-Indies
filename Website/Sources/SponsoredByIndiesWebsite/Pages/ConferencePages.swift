import Ignite

extension Pages {
    var directory: MarketingPage {
        let nextEdition = catalog.nextEdition(on: date)
        let today = date.formatted(Edition.dayStyle)
        let upcoming = catalog.editionsByDate.filter { $0.endDate >= today && $0.id != nextEdition?.id }
        let past = catalog.editionsByDate.filter { $0.endDate < today }.reversed()
        let undated = catalog.conferences.filter { catalog.editions(for: $0).isEmpty }
        return MarketingPage(path: "/conferences/", title: "Conferences", description: "Find iOS, Swift and Apple platform developer conferences and explore their indie bundles.") {
            Components.breadcrumb([("Home", "/"), ("Conferences", nil)])
            Tag("section") {
                Components.title("Find your", emphasis: "conference.")
                Text("Explore indie bundles for iOS, Swift and Apple developer conferences. Each edition has its own makers, contributions, and story.").class("lead")
            }.class("container", "page-intro")
            if let nextEdition {
                Tag("section") {
                    Components.heading("Next", "conference.", id: "next-conference-title")
                    Components.conferenceCard(
                        catalog.conference(for: nextEdition), edition: nextEdition, catalog: catalog)
                        .class("conference-card-featured")
                }.class("container", "section-space").aria(.labelledBy, "next-conference-title")
            }
            if !upcoming.isEmpty || !undated.isEmpty {
                Tag("section") {
                    Components.heading("Upcoming", "conferences.", id: "upcoming-conferences-title")
                    if !upcoming.isEmpty { conferenceGrid(upcoming) }
                    if !undated.isEmpty {
                        Text("Dates to be announced").font(.title3)
                        Tag("div") {
                            for conference in undated {
                                Components.conferenceCard(
                                    conference, edition: nil, catalog: catalog)
                                    .class("conference-card-compact")
                            }
                        }.class("conference-card-grid")
                    }
                }.class("container", "section-space").aria(.labelledBy, "upcoming-conferences-title")
            }
            if !past.isEmpty {
                Tag("section") {
                    Components.heading("Past", "conferences.", id: "past-conferences-title")
                    conferenceGrid(Array(past.prefix(2)))
                    if past.count > 2 {
                        // A native disclosure keeps the archive usable without JavaScript.
                        Tag("details") {
                            Tag("summary") {
                                Span("Show all past conferences").class("archive-show-all")
                                Span("Show fewer").class("archive-show-fewer")
                            }.class("btn", "btn-secondary")
                            conferenceGrid(Array(past.dropFirst(2)))
                        }.id("past-conferences-archive").class("conference-archive")
                    }
                }.class("container", "section-space").aria(.labelledBy, "past-conferences-title")
            }
            Components.audienceBenefits(for: [.conferences, .indies], title: "Get", emphasis: "involved.")
            Components.attendeeThanks
        }
    }

    private func conferenceGrid(_ editions: [Edition]) -> some HTML {
        Tag("div") {
            for edition in editions {
                Components.conferenceCard(catalog.conference(for: edition), edition: edition, catalog: catalog)
                    .class("conference-card-compact")
            }
        }.class("conference-card-grid")
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
