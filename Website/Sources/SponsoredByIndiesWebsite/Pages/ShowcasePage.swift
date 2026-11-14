import Ignite

extension Pages {
    func showcase(preview: Bool, asHostedPreview: Bool = false) -> MarketingPage {
        let sponsoredRoot = asHostedPreview ? "" : SiteIdentity.sponsored.baseURL(preview: preview)
        let showcasePath = asHostedPreview ? SiteIdentity.showcasePreviewPath : "/"
        return MarketingPage(
            path: showcasePath,
            title: asHostedPreview ? "By Indies preview" : "Independent projects and their makers",
            description: "Meet the independent apps, games, tools and courses supporting our conference community, and the people who make them.",
            isIndexable: !asHostedPreview, isShowcasePreview: asHostedPreview) {
            Tag("section") {
                Components.title("Wonderful projects.", emphasis: "By awesome indies.")
                Text("Small teams with big ideas, sharing what they make with our conference community. Discover their projects and get to know the people behind them.").class("lead")
                Text {
                    "Every project here contributes to a conference bundle through "
                    Link("Sponsored by Indies", target: sponsoredRoot + "/")
                    "."
                }
            }.class("container", "hero")
            Tag("section") {
                Text("Discover the projects").font(.title2).class("visually-hidden").id("projects-title")
                if catalog.showcaseProjects.isEmpty {
                    Text("Good things are taking shape. Meet our contributing projects here soon.").class("panel")
                } else {
                    Grid(catalog.showcaseProjects, alignment: .topLeading, spacing: .none) { project in
                        Section {
                            Components.showcaseCard(
                                project, indie: catalog.indie(withID: project.indieID),
                                editions: catalog.contributingEditions(for: project), catalog: catalog,
                                sponsoredRoot: sponsoredRoot, showcasePath: showcasePath)
                        }
                    }.columns(2).class("g-3", "showcase-grid")
                    Script(file: "/offer-sharing.mjs?v=\(DesignTokens.version)").attribute("type", "module")
                }
            }.class("container", "section-space").aria(.labelledBy, "projects-title")
            if !catalog.discoveryResources.isEmpty {
                Tag("section") {
                    Components.heading("More indie", "discoveries.", id: "discoveries-title")
                    Text("There’s a whole community celebrating independent makers. These newsletters, podcasts and showcases are lovely places to keep exploring.").class("lead")
                    Grid(catalog.discoveryResources, alignment: .topLeading, spacing: .none) { resource in
                        Section {
                            Tag("article") {
                                Text { Link(escaped(resource.name), target: escaped(resource.url)) }.font(.title3).margin(0)
                                Text(escaped(resource.description)).margin(0)
                            }.class("panel", "discovery-card")
                        }
                    }.columns(2).class("g-3", "discovery-grid")
                }.class("container", "section-space").aria(.labelledBy, "discoveries-title")
            }
            Tag("section") {
                Components.heading("Your project.", "A little extra.", id: "contribute-title")
                Text("Making something you’d love to share? Join a conference bundle and become part of this community.").class("lead")
                Components.button("Contribute your project", href: sponsoredRoot + "/participate/indies/")
            }.class("container", "section-space").aria(.labelledBy, "contribute-title")
        }
    }
}
