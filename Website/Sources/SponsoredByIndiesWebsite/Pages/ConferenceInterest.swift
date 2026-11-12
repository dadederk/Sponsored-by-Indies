import Ignite

struct ConferenceInterest {
    let catalog: Catalog

    var page: MarketingPage {
        MarketingPage(path: "/participate/conferences/", title: "For conference organisers", description: "Indie bundles for iOS, Swift and Apple platform developer conferences: the benefits, partnership, and how to express interest.") {
            Components.breadcrumb([("Get involved", "/participate/"), ("For conferences", nil)])
            Tag("section") {
                Components.title("More value.", emphasis: "Made together.")
                Text("Let indie makers help you offer more value with every conference ticket.").class("lead")
                Text("Bring your iOS, Swift or Apple developer community together with contributions from indies who know your conference.")
                if let contact = catalog.contactURL {
                    Components.button("Express conference interest", href: Components.interestURL(contact, subject: "Sponsored by Indies — conference interest", body: "Hi! I’d like to explore Sponsored by Indies for our conference.\r\n\r\nConference and website:\r\nNext edition and dates:\r\nLocation:\r\nExpected attendee numbers:\r\nAnything else we should know:\r\n"))
                    Text("This opens an email draft. Tell us about your conference, its next edition, and roughly how many people you expect.").class("contact-note")
                }
            }.class("container", "page-intro")
            Tag("section") {
                Components.heading("What your", "conference gets.", id: "benefits-title")
                Grid(alignment: .top, spacing: .none) {
                    Tag("article") {
                        Text("An extra for every attendee.").font(.title3)
                        Text("A bundle of free products and discounts on apps, games, books, courses, tools… from independent makers connected to your event.")
                    }.class("panel")
                    Tag("article") {
                        Text("A clearer ticket proposition.").font(.title3)
                        Text("Confirmed contributions and maximum potential savings you can include in your ticket messaging. Something tangible to help people see what they’re getting.")
                    }.class("panel")
                    Tag("article") {
                        Text("A bundle brought together.").font(.title3)
                        Text("We coordinate contributors and prepare an edition page with the makers, offers, terms, and attendee instructions. We work with you on the delivery plan.")
                    }.class("panel")
                }.columns(3).class("g-3")
            }.class("container", "section-space").aria(.labelledBy, "benefits-title")
            Section {
                Grid(alignment: .top, spacing: .none) {
                    partnershipRequests
                    partnershipProcess
                }.columns(1).class("section-grid", "row-cols-lg-2")
            }.class("container", "section-space")
        }
    }

    private var partnershipRequests: some HTML {
        Tag("section") {
            Components.heading("What we ask", "in return.", id: "asks-title")
            List {
                ListItem {
                    Text("Modest sponsor recognition.").font(.title3)
                    Text("A lower-tier place for Sponsored by Indies, keeping recognition proportionate and leaving the spotlight for sponsors contributing money.")
                }
                ListItem {
                    Text("A website link and an opening slide.").font(.title3)
                    Text("Link to your edition’s bundle and showcase its indie contributors during the conference opening.")
                }
                ListItem {
                    Text("Help reaching ticket holders.").font(.title3)
                    Text("Confirm eligibility and attendee numbers with us, help choose a practical delivery method, and get access to everyone included, including later ticket buyers.")
                }
            }.margin(.bottom, 0)
        }.aria(.labelledBy, "asks-title")
    }

    private var partnershipProcess: some HTML {
        Tag("section") {
            Components.heading("How we", "put it together.", id: "process-title")
            List {
                "Tell us about your conference and the community around it."
                "Agree the scope, recognition, timing, and attendee delivery with us."
                "Bring in connected indies and confirm their offers, capacity, and public profiles."
                "Share the confirmed bundle, deliver access, and learn from the edition together."
            }.listMarkerStyle(.ordered)
            if let note = catalog.partnershipNote { Text(escaped(note)) }
            if let contact = catalog.contactURL {
                Components.button("Tell us about your conference", href: Components.interestURL(contact, subject: "Sponsored by Indies — conference interest"))
            }
        }.aria(.labelledBy, "process-title")
    }
}
