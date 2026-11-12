import Ignite

extension Pages {
    var participate: MarketingPage {
        MarketingPage(path: "/participate/", title: "Get involved", description: "Support iOS, Swift and Apple platform developer conferences as an organiser or independent maker.") {
            Components.breadcrumb([("Home", "/"), ("Get involved", nil)])
            Tag("section") {
                Components.title("Get", emphasis: "involved.")
                Text("Hello, organisers and indie makers. Help bring a little extra to iOS, Swift and Apple developer conferences.").class("lead")
            }.class("container", "page-intro")
            Section {
                Grid(alignment: .top, spacing: .none) {
                    Tag("article") {
                        Text("For conference organisers").font(.title2).id("conferences-title")
                        Text("Let indie makers help you offer more value with every conference ticket. Find out what your event gets, what we ask in return, and how to get started.")
                        Components.button("Explore the conference partnership", href: "/participate/conferences/", style: .secondary)
                    }.id("conferences").class("panel").aria(.labelledBy, "conferences-title")
                    Tag("article") {
                        Text("For independent makers").font(.title2).id("indies-title")
                        Text("Support a conference community you care about. Share your app, game, book, course, tool… and tell us what you’d like to offer.")
                        Components.button("Propose an indie contribution", href: "/participate/indies/", style: .tertiary)
                    }.id("indies").class("panel").aria(.labelledBy, "indies-title")
                }.columns(2).class("g-3")
            }.class("container", "section-space")
        }
    }
}
