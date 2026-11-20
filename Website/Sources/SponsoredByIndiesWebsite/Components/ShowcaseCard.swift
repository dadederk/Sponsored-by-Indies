import Ignite

extension Components {
    static func showcaseCard(
        _ project: Project, indie: Indie, editions: [Edition], catalog: Catalog,
        sponsoredRoot: String, showcasePath: String
    ) -> some HTML {
        let people = indie.people ?? [IndiePerson(name: indie.name, websiteURL: indie.websiteURL, socials: indie.socials)]
        return Tag("article") {
            Section {
                HStack(alignment: .top, spacing: .small) {
                    projectHeading(project.name, url: project.websiteURL, icon: project.iconPath, level: .title2)
                        .class("showcase-project-title")
                    projectSharing(project, showcasePath: showcasePath)
                }.class("product-card-header")
                sharingFallback(label: "Link to " + project.name).margin(.top, .small)
            }
            Text(escaped(project.showcaseDescription)).margin(0)
            Section {
                Text(people.count == 1 ? "Meet the builder" : "Meet the builders")
                    .font(.title3)
                for person in people { builderRow(person) }
            }.class("showcase-builders")
            List(editions) { edition in
                ListItem {
                    Link(
                        escaped(catalog.conference(for: edition).name + " " + edition.label) + " bundle",
                        target: escaped(sponsoredRoot + edition.path(in: catalog) + "#" + project.bundleAnchor))
                    Span(" · " + escaped(edition.dateLabel))
                }
            }.font(.small).foregroundStyle(.secondary).class("showcase-contributions", "showcase-bundles")
        }.id(project.bundleAnchor).attribute("data-offer-sharing", "true").class("panel", "showcase-card")
            .padding(.bottom, 0)
    }

    private static func builderRow(_ person: IndiePerson) -> some HTML {
        HStack(alignment: .top, spacing: .none) {
            if let portrait = person.portraitPath {
                Image(decorative: ImageOptimization.path(for: portrait))
                    .frame(width: .px(DesignTokens.builderPortraitSize), height: .px(DesignTokens.builderPortraitSize))
                    .cornerRadius(DesignTokens.builderPortraitSize / 2)
                    .border(Color(hex: DesignTokens.palette.line), width: DesignTokens.builderPortraitBorderWidth)
                    .attribute("loading", "lazy").attribute("width", String(DesignTokens.builderPortraitSize))
                    .attribute("height", String(DesignTokens.builderPortraitSize))
                    .attribute("decoding", "async")
                    .class("builder-portrait")
            } else {
                Text(escaped(person.initials)).fontWeight(.semibold).margin(0)
                    .frame(width: .px(DesignTokens.builderPortraitSize), height: .px(DesignTokens.builderPortraitSize))
                    .cornerRadius(DesignTokens.builderPortraitSize / 2)
                    .background(Color(hex: DesignTokens.palette.tint)).foregroundStyle(Color(hex: DesignTokens.palette.blue))
                    .aria(.hidden, "true").class("builder-initials")
            }
            Section {
                Text(escaped(person.name)).fontWeight(.semibold).margin(0)
                if let bio = person.bio { Text(escaped(bio)).font(.small).margin(0) }
                if !person.showcaseLinks.isEmpty {
                    Text {
                        InlineForEach(Array(person.showcaseLinks.enumerated())) { index, link in
                            if index > 0 { Span(" · ").aria(.hidden, "true") }
                            builderLink(link.label, for: person.name, to: link.url)
                        }
                    }.font(.small).class("builder-links")
                }
            }
        }.class("builder-row")
    }

    private static func builderLink(_ label: String, for name: String, to url: String) -> some InlineElement {
        Link(target: escaped(url)) {
            escaped(label)
            Span(" for " + escaped(name)).class("visually-hidden")
        }
    }
}
